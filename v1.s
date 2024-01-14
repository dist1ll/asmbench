.text
.globl v1
.intel_syntax noprefix


.align 32
.needle: 
	.zero 32, 0x2a

v1:
	mov rdx, rax
	mov r11, 0
	vmovaps xmm0, xmmword ptr [rip + .needle]
	vmovaps ymm0, ymmword ptr [rip + .needle]
	jmp loop_ispc_pragma_x2

# ISPC version
.align 64
loop_og: # 494ms
	vmovdqu ymm1, ymmword ptr [rdx]
	vpcmpeqb        ymm2, ymm1, ymm0
	vpmovmskb       ecx, ymm2
	add     rdx, 32
	add     r11, 32
	test    ecx, ecx
	je      loop_og
	jmp end

# ISPC version, but without the redundant add
.align 64
loop_fixed: # 494ms
	vmovdqu ymm1, ymmword ptr [rdx]
	vpcmpeqb        ymm2, ymm1, ymm0
	vpmovmskb       ecx, ymm2
	add     rdx, 32
	test    ecx, ecx
	je      loop_fixed
	jmp end

.align 64
loop_ispc: # 483ms
	vpcmpeqb        ymm2, ymm0, ymmword ptr [rdx + 32]
	vpcmpeqb        ymm1, ymm0, ymmword ptr [rdx]
	vpor    ymm3, ymm1, ymm2
	add rdx, 64
	vpmovmskb       ecx, ymm3
	test    ecx, ecx
	je   loop_ispc
	jmp end

# unrolled 2x, ISPC pragma unroll
.align 64
loop_ispc_pragma_x2: # 481ms
	vpcmpeqb        ymm1, ymm0, ymmword ptr [rdx]
	vpmovmskb       ecx, ymm1
	test    ecx, ecx
	jne     end
	vpcmpeqb        ymm1, ymm0, ymmword ptr [rdx + 0x20]
	vpmovmskb       ecx, ymm1
	add     r11, 0x40
	add     rdx, 0x40
	test    ecx, ecx
	je      loop_ispc_pragma_x2

# no unrolling, NT load, w/o redundant add
.align 64
loop_nt: # 481ms
	vmovntdqa ymm1, ymmword ptr [rdx]
	vpcmpeqb        ymm2, ymm1, ymm0
	vpmovmskb       ecx, ymm2
	add     rdx, 32
	test    ecx, ecx
	je      loop_nt
	jmp end

# unrolled 2x, NT load, w/o redundant add
.align 64
loop_nt_x2: # 474ms
	vmovntdqa ymm1, ymmword ptr [rdx]
	vmovntdqa ymm2, ymmword ptr [rdx + 0x20]
	vpcmpeqb        ymm3, ymm1, ymm0
	vpcmpeqb        ymm4, ymm2, ymm0
	vpor ymm4, ymm4, ymm3
	vpmovmskb       ecx, ymm4
	add     rdx, 0x40
	test    ecx, ecx
	je      loop_nt_x2
	jmp end

# unrolled 4x, NT load, w/o redundant add
.align 64
loop_nt_x4: # 482ms
	vmovntdqa ymm1, ymmword ptr [rdx]
	vmovntdqa ymm2, ymmword ptr [rdx + 0x20]
	vpcmpeqb        ymm5, ymm1, ymm0
	vpcmpeqb        ymm6, ymm2, ymm0
	vpor ymm6, ymm6, ymm5

	vmovntdqa ymm3, ymmword ptr [rdx + 0x40]
	vmovntdqa ymm4, ymmword ptr [rdx + 0x60]
	vpcmpeqb        ymm7, ymm3, ymm0
	vpcmpeqb        ymm8, ymm4, ymm0
	vpor ymm8, ymm8, ymm7

	vpor ymm8, ymm8, ymm6
	vpmovmskb       ecx, ymm8
	add     rdx, 0x80
	test    ecx, ecx
	je      loop_nt_x4
	jmp end

# unrolled 2x, NT load, w/o redundant add, prefetch
.align 64
loop_nt_x2_prefetch: # 467ms
	prefetchnta      byte ptr [rdx + 0x80]
	vmovntdqa ymm1, ymmword ptr [rdx]
	vmovntdqa ymm2, ymmword ptr [rdx + 0x20]
	vpcmpeqb  ymm3, ymm1, ymm0
	vpcmpeqb  ymm4, ymm2, ymm0
	vpor ymm4, ymm4, ymm3
	vpmovmskb       ecx, ymm4
	add     rdx, 0x40
	test    ecx, ecx
	je      loop_nt_x2_prefetch
	jmp end

# tiled access
.align 64
loop_tiled: # 392ms
	# temporal load
	vmovaps ymm1, ymmword ptr [rdx]
	vmovaps ymm2, ymmword ptr [rdx + 0x20]
	vpcmpeqb        ymm5, ymm1, ymm0
	vpcmpeqb        ymm6, ymm2, ymm0
	vpor ymm6, ymm6, ymm5
	vpmovmskb       ecx, ymm6

	# streaming load
	vmovaps ymm3, ymmword ptr [rdx + 0x10000]
	vmovaps ymm4, ymmword ptr [rdx + 0x10020]
	vpcmpeqb        ymm7, ymm3, ymm0
	vpcmpeqb        ymm8, ymm4, ymm0
	vpor ymm8, ymm8, ymm7
	vpmovmskb       r11, ymm8

	add     rdx, 0x40

	mov r9, 0xffff
	and r9, rdx
	cmp r9, 0
	jne _loop_nt_mix_epi
	
	# increase tile
	add rdx, 0x10000

_loop_nt_mix_epi:
	or rcx, r11
	test    ecx, ecx
	je      loop_tiled
	jmp end

end:
	sub rdx, rax
	mov rax, rdx
	ret
	
