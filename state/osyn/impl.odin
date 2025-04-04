#+private
package osyn

import "core:fmt"
import "core:log"
import "core:math/rand"
import vmem "core:mem/virtual"
import "core:sync"
import "core:thread"
import "core:time"
import "../scheduler"

// get worker from context
get_worker :: proc() -> ^Worker {
	carrier := cast(^Ref_Carrier)context.user_ptr
	return carrier.worker
}

steal :: proc(this: ^Worker) {
	// steal from a random worker
	worker: ^Worker

	switch this.type {
	case .Generic:
		// generic workers should not be allowed to steal blocking task
		worker = rand.choice(this.coordinator.workers[:])
	case .Blocking:
		if rand.float32() > 0.5 {
			worker = rand.choice(this.coordinator.workers[:])
		} else {
			worker = rand.choice(this.coordinator.blocking_workers[:])
		}
	}

	if worker.id == this.id {
		// same id, and don't steal from self,
		return
	}

	// we don't steal from queues that doesn't have items
	queue_length := queue_length(&worker.localq)
	if queue_length == 0 {
		return
	}

	// steal half of the text once we find one
	for i in 1 ..= u64(queue_length / 2) { 	// TODO: need further testing
		elem, ok := queue_nonlocal_pop(&worker.localq)
		if !ok {
			log.error("failed to steal")
			return
		}

		queue_push(&this.localq, elem)
	}

}

// takes a worker context from the context
spawn_task :: proc(task: Task) {
	worker := get_worker()

	queue_push(&worker.localq, task)
}

// blocking tasks are pushed onto a queue
spawn_blocking_task :: proc(task: Task) {
	worker := get_worker()

	switch worker.type {
	case .Generic:
		gqueue_push(&worker.coordinator.global_blockingq, task)
	case .Blocking:
		queue_push(&worker.localq, task)
	}
}

spawn_unsafe_task :: proc(task: Task, coord: ^Coordinator) {
	gqueue_push(&coord.globalq, task)
}

spawn_unsafe_blocking_task :: proc(task: Task, coord: ^Coordinator) {
	gqueue_push(&coord.global_blockingq, task)
}

setup_thread :: proc(worker: ^Worker) -> ^thread.Thread {
	log.debug("setting up thread for", worker.id)

	log.debug("init queue")
	worker.localq = make_queue(Task, LOCAL_QUEUE_SIZE)

	thrd := thread.create(worker_runloop) // make a worker thread
	ctx := context

	log.debug("creating arena alloc")
	arena_alloc := vmem.arena_allocator(&worker.arena)

	ctx.allocator = arena_alloc

	ref_carrier := new_clone(Ref_Carrier{worker = worker, user_ptr = nil})
	ctx.user_ptr = ref_carrier

	thrd.init_context = ctx

	log.debug("built thread")
	return thrd

}

_init :: proc(coord: ^Coordinator, cfg: Config, init_task: Task) {
	log.debug("starting worker system")
	coord.worker_count = cfg.worker_count
	coord.blocking_worker_count = cfg.blocking_worker_count

	id_gen: u8

	// set up the global chan
	log.debug("setting up global channel")

	barrier := sync.Barrier{}
	sync.barrier_init(&barrier, int(cfg.worker_count + cfg.blocking_worker_count))

	coord.globalq = make_gqueue(Task)

	for i in 1 ..= coord.worker_count {
		worker := new(Worker)

		worker.id = id_gen
		id_gen += 1

		// load in the barrier
		worker.barrier_ref = &barrier
		worker.scheduler = scheduler.new_scheduler()
		worker.coordinator = coord
		worker.type = Worker_Type.Generic
		append(&coord.workers, worker)

		thrd := setup_thread(worker)
		thread.start(thrd)
		log.debug("started", i, "th worker")
	}

	for i in 1 ..= coord.blocking_worker_count {
		worker := new(Worker)

		worker.id = id_gen
		id_gen += 1

		// load in the barrier
		worker.barrier_ref = &barrier
		worker.scheduler = scheduler.new_scheduler()
		worker.coordinator = coord
		worker.type = Worker_Type.Blocking
		append(&coord.workers, worker)

		thrd := setup_thread(worker)
		thread.start(thrd)
		log.debug("started", i, "th blocking worker")
	}

	// chan send freezes indefinitely when nothing is listening to it
	// thus it is placed here
	log.debug("sending first task")

	gqueue_push(&coord.globalq, init_task)

	// theats the main thread as a worker too
	if cfg.use_main_thread == true {
		main_worker := new(Worker)
		main_worker.barrier_ref = &barrier
		main_worker.coordinator = coord

		main_worker.localq = make_queue(Task, LOCAL_QUEUE_SIZE)

		arena_alloc := vmem.arena_allocator(&main_worker.arena)

		main_worker.id = id_gen
		id_gen += 1

		context.allocator = arena_alloc

		ref_carrier := new_clone(Ref_Carrier{worker = main_worker, user_ptr = nil})
		context.user_ptr = ref_carrier

		shim_ptr: ^thread.Thread // not gonna use it

		append(&coord.workers, main_worker)
		coord.worker_count += 1

		worker_runloop(shim_ptr)
	}
}
