package olog

import "core:fmt"
import "core:strings"
import "core:os"
import "core:time"
import "core:log"
import "core:sync"
import "../ansi"

Level_Headers := [?]string{
	 0..<10 = "[DEBUG] ",
	10..<20 = "[INFO ] ",
	20..<30 = "[WARN ] ",
	30..<40 = "[ERROR] ",
	40..<50 = "[FATAL] ",
}

Default_Console_Logger_Opts :: log.Options{
	.Level,
	.Terminal_Color,
	.Short_File_Path,
	.Line,
	.Procedure,
} | log.Full_Timestamp_Opts

Default_File_Logger_Opts :: log.Options{
	.Level,
	.Short_File_Path,
	.Line,
	.Procedure,
} | log.Full_Timestamp_Opts


File_Console_Logger_Data :: struct {
	file_handle:  os.Handle,
	ident: string,
	mutex : sync.Mutex,
}

create_file_logger :: proc(h: os.Handle, lowest := log.Level.Debug, opt := log.Default_File_Logger_Opts, ident := "") -> log.Logger {
	data := new(File_Console_Logger_Data)
	data.file_handle = h
	data.ident = ident
	return log.Logger{file_logger_proc, data, lowest, opt}
}

destroy_file_logger :: proc(log: ^log.Logger) {
	data := cast(^File_Console_Logger_Data)log.data
	if data.file_handle != os.INVALID_HANDLE {
		os.close(data.file_handle)
	}
	free(data)
}

create_console_logger :: proc(lowest := log.Level.Debug, opt := log.Default_Console_Logger_Opts, ident := "") -> log.Logger {
	data := new(File_Console_Logger_Data)
	data.file_handle = os.INVALID_HANDLE
	data.ident = ident
	return log.Logger{console_logger_proc, data, lowest, opt}
}

destroy_console_logger :: proc(log: log.Logger) {
	free(log.data)
}

console_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
	data := cast(^File_Console_Logger_Data)logger_data
	sync.mutex_guard(&data.mutex);
	
	h: os.Handle = os.stdout if level <= log.Level.Error else os.stderr
	if data.file_handle != os.INVALID_HANDLE {
		h = data.file_handle
	}
	backing: [1024]byte //NOTE: 1024 might be too much for a header backing, unless somebody has really long paths.
	buf := strings.builder_from_bytes(backing[:])

	col := ansi.RESET
	switch level {
		case .Debug:   col = ansi.BLUE
		case .Info:	col = ansi.GREEN
		case .Warning: col = ansi.YELLOW
		case .Error, .Fatal: col = ansi.RED
	}
	
	do_location_header(options, &buf, location)
	
	if .Thread_Id in options {
		// NOTE(Oskar): not using context.thread_id here since that could be
		// incorrect when replacing context for a thread.
		fmt.sbprintf(&buf, "[{}] ", os.current_thread_id())
	}

	if data.ident != "" {
		fmt.sbprintf(&buf, "[%s] ", data.ident)
	}

	//TODO: When we have better atomics and such, make this thread-safe
	fmt.fprintf(h, "%s%s%s%s\n", strings.to_string(buf), col, text, ansi.RESET)
}

file_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
	data := cast(^File_Console_Logger_Data)logger_data
	
	sync.mutex_guard(&data.mutex);
	
	h: os.Handle = os.stdout if level <= log.Level.Error else os.stderr
	if data.file_handle != os.INVALID_HANDLE {
		h = data.file_handle
	}
	backing: [1024]byte //NOTE: 1024 might be too much for a header, unless somebody has really long paths.
	buf := strings.builder_from_bytes(backing[:])

	do_level_header(options, level, &buf)

	when time.IS_SUPPORTED {
		if log.Full_Timestamp_Opts & options != nil {
			fmt.sbprint(&buf, "[")
			t := time.now()
			y, m, d := time.date(t)
			h, min, s := time.clock(t)
			if .Date in options { fmt.sbprintf(&buf, "%d-%02d-%02d ", y, m, d)	}
			if .Time in options { fmt.sbprintf(&buf, "%02d:%02d:%02d", h, min, s) }
			fmt.sbprint(&buf, "] ")
		}
	}

	do_location_header(options, &buf, location)

	if .Thread_Id in options {
		fmt.sbprintf(&buf, "[{}] ", os.current_thread_id())
	}

	if data.ident != "" {
		fmt.sbprintf(&buf, "[%s] ", data.ident)
	}
	//TODO: When we have better atomics and such, make this thread-safe
	fmt.fprintf(h, "%s%s\n", strings.to_string(buf), text)
}

do_level_header :: proc(opts: log.Options, level: log.Level, str: ^strings.Builder) {

	col := ansi.RESET
	switch level {
	case .Debug:   col = ansi.BLUE
	case .Info:	col = ansi.RESET
	case .Warning: col = ansi.YELLOW
	case .Error, .Fatal: col = ansi.RED
	}

	if .Level in opts {
		if .Terminal_Color in opts {
			fmt.sbprint(str, col)
		}
		fmt.sbprint(str, Level_Headers[level])
		if .Terminal_Color in opts {
			fmt.sbprint(str, ansi.RESET)
		}
	}
}

do_location_header :: proc(opts: log.Options, buf: ^strings.Builder, location := #caller_location) {
	if log.Location_Header_Opts & opts == nil {
		return
	}
	fmt.sbprint(buf, "[")

	file := location.file_path
	if .Short_File_Path in opts {
		last := 0
		for r, i in location.file_path {
			if r == '/' {
				last = i+1
			}
		}
		file = location.file_path[last:]
	}

	if log.Location_File_Opts & opts != nil {
		fmt.sbprint(buf, file)
	}
	if .Line in opts {
		if log.Location_File_Opts & opts != nil {
			fmt.sbprint(buf, ":")
		}
		fmt.sbprint(buf, location.line)
	}

	if .Procedure in opts {
		if (log.Location_File_Opts | {.Line}) & opts != nil {
			fmt.sbprint(buf, ":")
		}
		fmt.sbprintf(buf, "%s()", location.procedure)
	}

	fmt.sbprint(buf, "] ")
}