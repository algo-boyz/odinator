package gc

import "base:intrinsics"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:sync"
import "core:testing"

when ODIN_OS == .Windows {
	foreign import libgc "libgc.lib"
} else {
	foreign import libgc "system:gc"
}

Config :: struct {
	incremental:  bool,     // Enable incremental collection
	parallel:     bool,     // Enable parallel collection
	initial_heap: int,     	// Initial heap size in bytes
	max_heap:     int,     	// Maximum heap size in bytes
	log_level:    Log_Level,
}

Log_Level :: enum {
	None,
	Error,
	Warn,
	Info,
	Debug,
}

// Memory statistics
Stats :: struct {
	heap_size: int,         // Current heap size in bytes
	total_allocated: int,   // Total allocated memory in bytes
	free_bytes: int,        // Free memory in bytes
	collection_count: int,  // Number of collections performed
	collection_time: int,   // Total time spent collecting (ms)
}

// Type for custom finalizers
Finalizer :: #type proc(obj: rawptr)
warn_proc :: #type proc "c" (msg: ^c.char, value: c.ulong)

@(link_prefix = "GC_")
@(default_calling_convention = "c")
foreign libgc {
	malloc :: proc(size: c.size_t) -> rawptr ---
	malloc_atomic :: proc(size: c.size_t) -> rawptr ---
	malloc_uncollectable :: proc(size: c.size_t) -> rawptr ---
	realloc :: proc(ptr: rawptr, size: c.size_t) -> rawptr ---
	free :: proc(ptr: rawptr) ---
	set_warn_proc :: proc(p: warn_proc) -> warn_proc ---
}

@(link_prefix = "GC_")
@(default_calling_convention = "c")
foreign libgc {
	init :: proc() ---
	gcollect :: proc() ---
	enable_incremental :: proc() ---
	// Thread support
	allow_register_threads :: proc(value: c.int) ---
	register_my_thread :: proc(sb: ^c.char) -> c.int ---
	unregister_my_thread :: proc() ---
	// Memory stats
	get_heap_size :: proc() -> c.size_t ---
	get_free_bytes :: proc() -> c.size_t ---
	get_bytes_since_gc :: proc() -> c.size_t ---
	get_total_bytes :: proc() -> c.size_t ---
	// Finalizers
	register_finalizer :: proc(obj: rawptr, fn: rawptr, cd: rawptr, ofn: ^rawptr, ocd: ^rawptr) -> c.int ---
	// Tuning params
	set_full_freq :: proc(value: c.int) ---
	set_time_limit :: proc(value: c.int) ---
	set_max_heap_size :: proc(size: c.size_t) ---
	// Weak references
	malloc_weak :: proc(size: c.size_t) -> rawptr ---
	general_register_disappearing_link :: proc(link: ^rawptr, obj: rawptr) -> c.int ---
}

@(private)
log_level: Log_Level = .None

@(private)
log :: proc(level: Log_Level, format: string, args: ..any) {
	if int(level) <= int(log_level) {
		fmt.printf("[GC %v] ", level)
		fmt.printf(format, ..args)
		fmt.println()
	}
}

@(private)
c_warn_proc :: proc "c" (msg: ^c.char, value: c.ulong) {
	if log_level >= .Warn {
		// c_str := string(cstring(msg))
		// log(.Warn, "%s (%d)", c_str, value)
	}
}

@(private)
do_alloc :: proc(
	mode: runtime.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	$func: proc "c" (size: c.size_t) -> rawptr,
) -> (
	[]u8,
	runtime.Allocator_Error,
) {
    // ONLY perform alignment check for allocation/resize modes,
    // as alignment is irrelevant for free modes.
    if mode == .Alloc || mode == .Alloc_Non_Zeroed || mode == .Resize {
        // Boehm GC should handle common pow2 alignments like 8, 16, etc.
        if alignment <= 0 || intrinsics.count_ones(alignment) != 1 {
            log(.Error, "Invalid alignment (not positive power of 2): %d for mode %v", alignment, mode)
            return nil, .Invalid_Argument
        }
    }
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		p := func(c.size_t(size))
		if p == nil {
			log(.Error, "Failed to allocate %d bytes", size)
			return nil, .Out_Of_Memory
		}
		return slice.bytes_from_ptr(p, size), .None
	case .Free:
		free(old_memory)
		return nil, .None
	case .Free_All:
		gcollect()
		return nil, .None
	case .Resize:
		p := realloc(old_memory, c.size_t(size))
		if p == nil {
			log(.Error, "Failed to resize allocation to %d bytes", size)
			return nil, .Out_Of_Memory
		}
		return slice.bytes_from_ptr(p, size), .None
	}
	return nil, .Mode_Not_Implemented
}

// Default allocator
allocator :: mem.Allocator {
	procedure = proc(
		allocator_data: rawptr,
		mode: runtime.Allocator_Mode,
		size, alignment: int,
		old_memory: rawptr,
		old_size: int,
		location := #caller_location,
	) -> (
		[]u8,
		runtime.Allocator_Error,
	) {
		return do_alloc(mode, size, alignment, old_memory, malloc)
	},
}

// Atomic allocator for strings and non-pointer data
atomic_allocator :: mem.Allocator {
	procedure = proc(
		allocator_data: rawptr,
		mode: runtime.Allocator_Mode,
		size, alignment: int,
		old_memory: rawptr,
		old_size: int,
		location := #caller_location,
	) -> (
		[]u8,
		runtime.Allocator_Error,
	) {
		return do_alloc(mode, size, alignment, old_memory, malloc_atomic)
	},
}

// Uncollectable allocator for root objects
uncollectable_allocator :: mem.Allocator {
	procedure = proc(
		allocator_data: rawptr,
		mode: runtime.Allocator_Mode,
		size, alignment: int,
		old_memory: rawptr,
		old_size: int,
		location := #caller_location,
	) -> (
		[]u8,
		runtime.Allocator_Error,
	) {
		return do_alloc(mode, size, alignment, old_memory, malloc_uncollectable)
	},
}

// Weak reference allocator
weak_allocator :: mem.Allocator {
	procedure = proc(
		allocator_data: rawptr,
		mode: runtime.Allocator_Mode,
		size, alignment: int,
		old_memory: rawptr,
		old_size: int,
		location := #caller_location,
	) -> (
		[]u8,
		runtime.Allocator_Error,
	) {
		return do_alloc(mode, size, alignment, old_memory, malloc_weak)
	},
}

// Default configuration
DEFAULT_CONFIG :: Config {
	incremental = false,
	parallel = true,
	log_level = .Warn,
	initial_heap = 0,
	max_heap = 0, // WARN: Unlimited
}

initialize :: proc(config := DEFAULT_CONFIG) -> runtime.Context {
	init()
	
	// Set log level
	log_level = config.log_level
	set_warn_proc(c_warn_proc)
	
	// Configure GC behavior
	if config.incremental {
		enable_incremental()
		log(.Info, "Incremental collection enabled")
	}
	
	// Set heap size constraints
	if config.max_heap > 0 {
		set_max_heap_size(c.size_t(config.max_heap))
		log(.Info, "Set maximum heap size to %d bytes", config.max_heap)
	}
	
	// Enable thread registration
	allow_register_threads(1)
	
	// Create and return a context with our allocator
	ctx := context
	ctx.allocator = allocator
	ctx.temp_allocator = allocator
	
	log(.Info, "GC initialized successfully")
	return ctx
}

// Explicitly force a garbage collection
collect :: proc() {
	log(.Info, "Manual collection triggered")
	gcollect()
}

// Get current memory statistics
get_stats :: proc() -> Stats {
	stats := Stats{
		heap_size = int(get_heap_size()),
		free_bytes = int(get_free_bytes()),
		total_allocated = int(get_total_bytes()),
		// Note: collection_count and collection_time require additional tracking
	}
	return stats
}

// Register current thread with the GC
register_thread :: proc() -> bool {
	stack_base: [1]byte
	result := register_my_thread(&stack_base[0])
	success := result == 0
	if success {
		log(.Info, "Thread registered successfully")
	} else {
		log(.Error, "Failed to register thread")
	}
	return success
}

// Unregister current thread from the GC
unregister_thread :: proc() {
	unregister_my_thread()
	log(.Info, "Thread unregistered")
}

// Add a finalizer function to an object
add_finalizer :: proc(obj: rawptr, fn: Finalizer) -> bool {
	result := register_finalizer(obj, rawptr(fn), nil, nil, nil)
	return result == 0
}

// Create a weak reference to an object
make_weak_ref :: proc(obj: rawptr) -> (^rawptr, bool) {
	link := cast(^rawptr)malloc(size_of(rawptr))
	if link == nil {
		return nil, false
	}
	
	link^ = obj
	result := general_register_disappearing_link(link, obj)
	if result == 0 {
		free(link)
		return nil, false
	}
	
	return link, true
}

// String formatting utilities
sprint :: proc(args: ..any, sep: string = " ") -> string {
	context.allocator = atomic_allocator
	return fmt.aprint(..args, sep = sep)
}

sprintln :: proc(args: ..any, sep: string = " ") -> string {
	context.allocator = atomic_allocator
	return fmt.aprintln(..args, sep = sep)
}

sprintf :: proc(format: string, args: ..any) -> string {
	context.allocator = atomic_allocator
	return fmt.aprintf(format, ..args)
}

// Arena allocator
Arena :: struct {
	objects: [dynamic]rawptr,
	mutex: sync.Mutex,
}

// Create a new arena allocator
new_arena :: proc() -> ^Arena {
	arena := new(Arena, allocator)
	arena.objects = make([dynamic]rawptr, allocator)
	return arena
}

// Allocate memory in a arena
arena_alloc :: proc(arena: ^Arena, size: int) -> rawptr {
	sync.mutex_lock(&arena.mutex)
	defer sync.mutex_unlock(&arena.mutex)
	
	ptr := malloc(c.size_t(size))
	if ptr != nil {
		append(&arena.objects, ptr)
	}
	return ptr
}

// Free all memory in a arena
arena_free :: proc(arena: ^Arena) {
	sync.mutex_lock(&arena.mutex)
	defer sync.mutex_unlock(&arena.mutex)
	
	for obj in arena.objects {
		free(obj)
	}
	clear(&arena.objects)
}

// Destroy a arena
destroy_arena :: proc(arena: ^Arena) {
	arena_free(arena)
	delete(arena.objects)
	free(arena)
}

// Unit test for basic functionality
@(test)
test_basic :: proc(t: ^testing.T) {
	ctx := initialize()
	context = ctx
	
	// Test allocation
	data := make([]int, 100)
	testing.expect(t, len(data) == 100, "Failed to allocate memory")
	
	// Test collection
	collect()
	
	// Test string formatting
	str := sprintf("Test %d", 123)
	testing.expect(t, str == "Test 123", "String formatting failed")
	
	// Test stats
	stats := get_stats()
	testing.expect(t, stats.heap_size > 0, "Invalid heap size")
}

// Unit test for arenas
@(test)
test_arena :: proc(t: ^testing.T) {
	ctx := initialize()
	context = ctx
	
	arena := new_arena()
	defer destroy_arena(arena)
	
	// Allocate some objects
	for i in 0..<100 {
		ptr := arena_alloc(arena, 1024)
		testing.expect(t, ptr != nil, "Arena allocation failed")
	}
	
	// Free all at once
	arena_free(arena)
	testing.expect(t, len(arena.objects) == 0, "Arena free failed")
}