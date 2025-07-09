package cdl // concurrent_dynamic_list

import "core:sync"
import "core:mem"

Concurrent_Array_List :: struct($T: typeid) {
    allocator: mem.Allocator,
    rwlock: sync.RW_Mutex,
    items: [dynamic]T,
}

init :: proc(allocator: mem.Allocator, $T: typeid) -> Concurrent_Array_List(T) {
    return Concurrent_Array_List(T){
        allocator = allocator,
        rwlock = {},
        items = make([dynamic]T, allocator),
    }
}

deinit :: proc(self: ^Concurrent_Array_List($T)) {
    sync.lock(&self.rwlock)
    defer sync.unlock(&self.rwlock)
    delete(self.items)
}

get :: proc(self: ^Concurrent_Array_List($T), index: int) -> T {
    sync.shared_lock(&self.rwlock)
    defer sync.shared_unlock(&self.rwlock)
    return self.items[index]
}

try_get :: proc(self: ^Concurrent_Array_List($T), index: int) -> (T, bool) {
    if !sync.try_shared_lock(&self.rwlock) {
        return {}, false
    }
    defer sync.shared_unlock(&self.rwlock)
    
    if index >= len(self.items) {
        return {}, false
    }
    return self.items[index], true
}

count :: proc(self: ^Concurrent_Array_List($T)) -> int {
    sync.shared_lock(&self.rwlock)
    defer sync.shared_unlock(&self.rwlock)
    return len(self.items)
}

insert :: proc(self: ^Concurrent_Array_List($T), index: int, value: T) -> mem.Allocator_Error {
    sync.lock(&self.rwlock)
    defer sync.unlock(&self.rwlock)
    
    if index > len(self.items) {
        return .Out_Of_Memory // Or custom error
    }
    
    inject_at(&self.items, index, value) or_return
    return nil
}

try_insert :: proc(self: ^Concurrent_Array_List($T), index: int, value: T) -> (bool, mem.Allocator_Error) {
    if !sync.try_lock(&self.rwlock) {
        return false, nil
    }
    defer sync.unlock(&self.rwlock)
    
    if index > len(self.items) {
        return true, .Out_Of_Memory
    }
    
    inject_at(&self.items, index, value) or_return
    return true, nil
}

// Fixed: Use builtin.append to avoid naming conflict
push :: proc(self: ^Concurrent_Array_List($T), value: T) -> mem.Allocator_Error {
    sync.lock(&self.rwlock)
    defer sync.unlock(&self.rwlock)
    builtin.append(&self.items, value) or_return
    return nil
}

try_push :: proc(self: ^Concurrent_Array_List($T), value: T) -> (ok: bool, err: mem.Allocator_Error) {
    if !sync.try_lock(&self.rwlock) {
        ok = false
        err = nil
        return
    }
    defer sync.unlock(&self.rwlock)
    append(&self.items, value) or_return
    ok = true
    err = nil
    return
}

pop_or_null :: proc(self: ^Concurrent_Array_List($T)) -> (T, bool) {
    sync.lock(&self.rwlock)
    defer sync.unlock(&self.rwlock)
    
    if len(self.items) == 0 {
        return {}, false
    }
    
    value := pop(&self.items)
    return value, true
}