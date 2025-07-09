#+build darwin
package os

import "core:fmt"
import "core:os/os2"

_install_apps :: proc() {
	r, w, err := os2.pipe()
    if err != nil {
        fmt.eprintf("Error creating pipe: %v\n", err)
    }
    defer os2.close(w)

	p: os2.Process
    p, err = os2.process_start(
        {
            command = {"brew", "install", "odin"},
            stdout = w,
        },
    )
    if err != nil {
        fmt.eprintf("Error starting process: %v\n", err)
    }

    output: []byte
	output, err = os2.read_entire_file(r, context.temp_allocator)
    if err != nil {
        fmt.eprintf("Error reading from pipe: %v\n", err)
    }

	_, err = os2.process_wait(p)
    if err != nil {
        fmt.eprintf("Error waiting for process: %v\n", err)
    }
	fmt.print(string(output))
}