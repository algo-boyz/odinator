package main

import "core:fmt"
import "core:mem"
import "core:strconv"
import "core:sync"
import "core:sync/chan"
import "core:thread"
import "core:time"

// https://rm4n0s.github.io/posts/2-go-devs-should-learn-odin/#threads
Parent_Enum :: enum {
	Father,
	Mother,
}

Food_From_Father :: struct {
	papa_index: int,
}

Food_From_Mother :: struct {
	mama_index: int,
}

Food :: union {
	Food_From_Father,
	Food_From_Mother,
}


KidData :: struct {
	kids_wait_group: ^sync.Wait_Group,
	mouth:           ^chan.Chan(Food, chan.Direction.Recv),
}

ParentData :: struct {
	parent_type:        Parent_Enum,
	num_foods:          int,
	parents_wait_group: ^sync.Wait_Group,
	mouth:              ^chan.Chan(Food, chan.Direction.Send),
	mouth_mutex:        ^sync.Mutex,
}

parent_task :: proc(t: ^thread.Thread) {
	data := (cast(^ParentData)t.data)
	fmt.println(data.parent_type, "starts feeding")

	for i in 1 ..= data.num_foods {
		food: Food
		if data.parent_type == .Mother {
			food = Food_From_Mother {
				mama_index = i,
			}
		}
		if data.parent_type == .Father {
			food = Food_From_Father {
				papa_index = i,
			}
		}
		sync.mutex_lock(data.mouth_mutex)
		chan.send(data.mouth^, food)
		sync.mutex_unlock(data.mouth_mutex)
		// wait to throw new food
		time.sleep(500 * time.Millisecond)
	}
	sync.wait_group_done(data.parents_wait_group)
	fmt.printfln("%v's feeding stopped", data.parent_type)

}

kid_task :: proc(t: thread.Task) {
	data := (cast(^KidData)t.data)
	fmt.println("kid", t.user_index, "opens mouth")
	for {
		msg, ok := chan.recv(data.mouth^)
		if !ok {
			fmt.println("mouth closed for kid", t.user_index)
			break
		}
		switch food in msg {
		case Food_From_Father:
			fmt.println("kid", t.user_index, 
              "received food", food.papa_index, 
              "from father")
		case Food_From_Mother:
			fmt.println("kid", t.user_index, 
              "received food", food.mama_index, 
              "from mother")
		}
		// wait to chew their food
		time.sleep(time.Second)
	}
	fmt.println("kid", t.user_index, "finished eating")
	sync.wait_group_done(data.kids_wait_group)
	fmt.printfln("kid %d went to bed", t.user_index)
}

main :: proc() {
	parents_wg: sync.Wait_Group
	kids_wg: sync.Wait_Group
	num_kids := 5

	// create feeding pipe
	mouth, err := chan.create(chan.Chan(Food), context.allocator)
	defer chan.destroy(mouth)
	mouth_mutex := sync.Mutex{}

	// create mama bird
	mama_mouth := chan.as_send(mouth)
	mama_thread := thread.create(parent_task)
	defer thread.destroy(mama_thread)
	mama_thread.init_context = context
	mama_thread.user_index = 1
	mama_thread.data = &ParentData {
		parent_type        = .Mother,
		num_foods          = 8, // with more food
		parents_wait_group = &parents_wg,
		mouth              = &mama_mouth,
		mouth_mutex        = &mouth_mutex,
	}

	// create lazy father bird
	papa_mouth := chan.as_send(mouth)
	papa_thread := thread.create(parent_task)
	defer thread.destroy(papa_thread)
	papa_thread.init_context = context
	papa_thread.user_index = 2
	papa_thread.data = &ParentData {
		parent_type        = .Father,
		num_foods          = 6, // with less food
		parents_wait_group = &parents_wg,
		mouth              = &papa_mouth,
		mouth_mutex        = &mouth_mutex,
	}

	sync.wait_group_add(&parents_wg, 2)

	thread.start(mama_thread)
	thread.start(papa_thread)

	// create a nest for kids
	nest: thread.Pool
	thread.pool_init(&nest, 
        allocator = context.allocator, 
        thread_count = num_kids)

	defer thread.pool_destroy(&nest)

	sync.wait_group_add(&kids_wg, num_kids)
	for i in 1 ..= num_kids {
		kid_mouth := chan.as_recv(mouth)
		data := &KidData{
            kids_wait_group = &kids_wg, 
            mouth = &kid_mouth
        }

		// add kid to the nest
		thread.pool_add_task(
			&nest,
			allocator = context.allocator,
			procedure = kid_task,
			data = rawptr(data),
			user_index = i,
		)
	}

	thread.pool_start(&nest)


	// first we wait for parents to stop feeding kids
	sync.wait_group_wait(&parents_wg)
	fmt.println("all parents stopped feeding them")

	// everybody closes their mouths
	chan.close(mouth)
	fmt.println("kids close their mouths")

	// we wait for all kids to sleep
	sync.wait_group_wait(&kids_wg)

	fmt.println("all kids slept")

	// run this or else the program will never close
	thread.pool_finish(&nest)

}