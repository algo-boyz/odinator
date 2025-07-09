package odin_tcp_aes

import "core:fmt"
import "core:crypto"
import "core:crypto/aes"

make_gcm :: proc(key: []byte) -> (gcm: aes.Context_GCM) {
	aes.init_gcm(&gcm, key)
	return
}

make_key :: proc() -> (res: [32]byte) {
	crypto.rand_bytes(res[:])
	return
}

encrypt :: proc(plain, aad: []byte, ctx: ^aes.Context_GCM, tag_len: int=16, iv_len: int=12) -> []byte {
	res := make_slice([]byte, len(plain) + tag_len + iv_len)

	iv := res[:iv_len]
	crypto.rand_bytes(iv)

	str := res[iv_len:(len(res) - tag_len)]
	tag := res[len(res) - tag_len:]

	aes.seal_gcm(ctx, str, tag, iv, aad, plain)
	return res
}

decrypt :: proc(str, aad: []byte, ctx: ^aes.Context_GCM, tag_len: int=16, iv_len: int=12) -> []byte {
	res := make_slice([]byte, len(str) - tag_len - iv_len)

	iv := str[:iv_len]
	enc := str[iv_len:(len(str) - tag_len)]
	tag := str[len(str) - tag_len:]

	ok := aes.open_gcm(ctx, res, iv, aad, enc, tag)
	if !ok do fmt.println("error decrypting message")

	return res
}