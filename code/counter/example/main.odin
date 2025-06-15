package main

import "core:mem"
import "../../util"
import "../"

main :: proc () {
	context.logger = util.create_console_logger(.Info)
	defer util.destroy_console_logger(context.logger)
	
	util.init_tracking_allocators()
	{
		tracker : ^mem.Tracking_Allocator
		context.allocator = util.make_tracking_allocator(tracker_res = &tracker) //This will use the backing allocator,
		
		counter.code_count()
				
		free_all(context.temp_allocator)
	}
	util.print_tracking_memory_results()
	util.destroy_tracking_allocators()
}