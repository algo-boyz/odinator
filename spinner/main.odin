package text_spinner

import "core:time"
import "core:thread"
import "core:fmt"
import "core:sync"

// Spinner_Type defines the visual style of the spinner.
Spinner_Type :: enum {
	QUARTER,
	SEMI,
	OUTLINE,
	BARS,
	CLASSIC,
}

// Animation_State holds all the runtime information for an active animation.
// This state is shared between the main thread and the animation thread.
Animation_State :: struct {
	index:    int,
	frames:   []string,
	running:  bool,
	mutex:    sync.Mutex,
	text_ptr: ^string, // Pointer to the string in the main thread to update
	thread:   ^thread.Thread,
}

// Text_Spinner is a factory struct that contains the frame data for all spinner types.
Text_Spinner :: struct {
	quarter_frames: []string,
	semi_frames:    []string,
	outline_frames: []string,
	bars_frames:    []string,
	classic_frames: []string,
}

// make_spinner initializes a new Text_Spinner with all frame definitions.
make_spinner :: proc() -> Text_Spinner {
	return Text_Spinner{
		quarter_frames = {"◷", "◶", "◵", "◴"},
		semi_frames    = {"◓", "◑", "◒", "◐"},
		outline_frames = {"◝", "◞", "◟", "◜"},
		bars_frames    = {" ", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂", " "},
		classic_frames = {"|", "/", "—", "\\"},
	}
}

// animation_proc is the procedure that runs on a separate thread.
// It continuously updates the shared string with the next animation frame.
animation_proc :: proc(t: ^thread.Thread) {
	// The state is passed to the thread via the 'data' field.
	state := cast(^Animation_State)t.data
	interval := 100 * time.Millisecond

	for {
		// Lock the mutex to ensure safe access to shared data.
		sync.mutex_lock(&state.mutex)
		
		// Check if the main thread has requested a stop.
		if !state.running {
			sync.mutex_unlock(&state.mutex)
			break // Exit the loop to terminate the thread.
		}

		// Update the string that text_ptr points to with the current frame.
		state.text_ptr^ = state.frames[state.index]

		// Advance to the next frame, wrapping around at the end.
		state.index = (state.index + 1) % len(state.frames)
		
		sync.mutex_unlock(&state.mutex)

		// Wait for a short interval before the next frame.
		time.sleep(interval)
	}

	// Final cleanup: clear the spinner text once stopped.
	sync.mutex_lock(&state.mutex)
	state.text_ptr^ = ""
	sync.mutex_unlock(&state.mutex)
}

// animate creates and starts a new animation thread.
// It returns a pointer to the shared Animation_State.
animate :: proc(spinner: ^Text_Spinner, spinner_type: Spinner_Type, text_ptr: ^string) -> ^Animation_State {
	state := new(Animation_State)
	state.index = 0
	state.running = true
	state.text_ptr = text_ptr

	// Select the correct frame set based on the requested spinner type.
	switch spinner_type {
	case .QUARTER:
		state.frames = spinner.quarter_frames
	case .SEMI:
		state.frames = spinner.semi_frames
	case .OUTLINE:
		state.frames = spinner.outline_frames
	case .BARS:
		state.frames = spinner.bars_frames
	case .CLASSIC: // FIXED: Was missing, would cause a crash if used.
		state.frames = spinner.classic_frames
	}

	// If for some reason the frames are not set, prevent a crash.
	if len(state.frames) == 0 {
		fmt.eprintf("Error: Spinner type %v has no frames defined.\n", spinner_type)
		return nil
	}

	// Create the thread, passing our procedure.
	state.thread = thread.create(animation_proc)
	// Pass the state struct to the new thread.
	state.thread.data = state
	// CRITICAL: Propagate the parent's context (for allocators, loggers, etc.).
	state.thread.init_context = context
	
	thread.start(state.thread)

	return state
}

// stop_animation signals the animation thread to stop and waits for it to finish.
stop_animation :: proc(state: ^Animation_State) {
	if state == nil || state.thread == nil {
		return
	}
	
	// Lock the mutex to safely change the 'running' flag.
	sync.mutex_lock(&state.mutex)
	state.running = false
	sync.mutex_unlock(&state.mutex)

	// Wait for the animation thread to finish its execution.
	thread.join(state.thread)
}

// destroy_animation stops the animation and cleans up all associated resources.
destroy_animation :: proc(state: ^Animation_State) {
	if state == nil {
		return
	}
	
	stop_animation(state)

	if state.thread != nil {
		thread.destroy(state.thread)
	}
	
	free(state) // Free the memory allocated for the Animation_State.
}


// main procedure to demonstrate the text spinners.
main :: proc() {
	spinner := make_spinner()
	display_text := "" // This string will be updated by the animation thread.

	fmt.println("Starting spinner demo...")

	// Define the list of spinners we want to demonstrate.
	spinner_types := []Spinner_Type{.QUARTER, .SEMI, .OUTLINE, .BARS, .CLASSIC}
	names := []string{"Quarter", "Semi", "Outline", "Bars", "Classic"}

	for stype, i in spinner_types {
		fmt.printf("\nDemo: %s spinner\n", names[i])

		// Start the animation, passing a pointer to our display_text.
		anim_state := animate(&spinner, stype, &display_text)
		if anim_state == nil {
			continue // Skip if animation failed to start.
		}

		// Let the animation run for 3 seconds while we print updates.
		demo_end_time := time.now()._nsec + 18000000000 // 3 seconds in nanoseconds
		for time.now()._nsec < demo_end_time {
			
			// To read the display_text, we must lock the mutex to prevent a race condition.
			sync.mutex_lock(&anim_state.mutex)
			current_text_frame := display_text
			sync.mutex_unlock(&anim_state.mutex)

			// Print the current spinner frame, using \r to overwrite the same line.
			fmt.printf("\r[%s] Loading...", current_text_frame)
			
			// Sleep briefly. This controls the refresh rate of the display,
			// not the animation itself.
			time.sleep(100 * time.Millisecond)
		}

		// Stop the animation and free all resources.
		destroy_animation(anim_state)
		
		// Print a final "complete" message, with spaces to clear the line.
		fmt.printf("\r[✓] Complete!          \n")
		time.sleep(500 * time.Millisecond) // Pause briefly between demos.
	}

	fmt.println("\nSpinner demo completed!")
}
