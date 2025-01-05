SYS_EXIT equ 0x2000001
SYS_READ equ 0x2000003
SYS_WRITE equ 0x2000004

FD_STDIN equ 0
FD_STDOUT equ 1
FD_STDERR equ 2

NUMBER_SIZE equ 64
BASE_SIZE equ 64
XDIGITS_SIZE equ 128
XCHARS_SIZE equ XDIGITS_SIZE

NUM_LEN equ 16
BASE_LEN equ 16

section .bss
  number resb NUMBER_SIZE
  base resb BASE_SIZE
  tempchar resb 1
  xdigits resb XDIGITS_SIZE
  xchars resb XCHARS_SIZE

section .data
  numberin_s db "Enter the non-negative denary integer to convert (0..): "
  numberin_l equ $ - numberin_s
  basein_s db "Enter the base to convert to (2..=36): "
  basein_l equ $ - basein_s
  convoutl_s db " in base "
  convoutl_l equ $ - convoutl_s
  convoutr_s db " is: "
  convoutr_l equ $ - convoutr_s
  convoutend_s db ".", 10
  convoutend_l equ $ - convoutend_s
  err_invalid_digitl_s db "Invalid base 10 digit: '"
  err_invalid_digitl_l equ $ - err_invalid_digitl_s
  err_invalid_digitr_s db "', must be between '0' and '9'", 10
  err_invalid_digitr_l equ $ - err_invalid_digitr_s
  err_invalid_basel_s db "Invalid base "
  err_invalid_basel_l equ $ - err_invalid_basel_s 
  err_invalid_baser_s db ", must be within the range 2..=36", 10
  err_invalid_baser_l equ $ - err_invalid_baser_s 

section .text
  global _start

_start:
  ; ask for number
  mov rdi, numberin_s
  mov rsi, numberin_l
  call _print
  ; read number
  mov rdi, number
  mov rsi, NUM_LEN
  call _input
  ; calculate number length
  mov r8, rax
  dec r8 ; without line feed
  ; convert number from string to number
  call _atoi
  mov r9, rax ; save number
  ; ask for base
  mov rdi, basein_s
  mov rsi, basein_l
  call _print
  ; read base
  mov rdi, base
  mov rsi, BASE_LEN
  call _input
  ; calculate base length
  mov rdx, rax
  dec rdx ; without line feed
  ; convert base from string to number
  call _atoi
  mov r11, rax ; save base
  ; validate converted base
  mov rdi, r11
  mov rsi, base
  call _validate_base
  ; print message
  call _putlf
  mov rdi, number
  mov rsi, r8
  call _print
  mov rdi, convoutl_s
  mov rsi, convoutl_l
  call _print
  mov rdi, base
  mov rsi, rdx
  call _print
  mov rdi, convoutr_s
  mov rsi, convoutr_l
  call _print
  ; convert number to base
  mov rdi, r9
  mov rsi, r11
  mov rdx, xchars
  mov rcx, xdigits
  call _convert_base
  ; print number
  mov rdi, xchars
  mov rsi, rax
  call _print
  ; print .\n
  mov rdi, convoutend_s
  mov rsi, convoutend_l
  call _print
  ; exit peacefully
  mov rdi, 0
  call _exit

; writes rdx bytes from the buffer [rsi] to the file
; descriptor rdi
_write:
  ; save state
  push rcx
  push r11
  push rax
  ; syscall
  mov rax, SYS_WRITE
  syscall
  ; restore state
  pop rax
  pop r11
  pop rcx
  ret

; prints rsi bytes to stdout from the buffer [rdi]
_print:
  ; save state
  push rdx
  push rsi
  push rdi
  ; write
  mov rdx, rsi
  mov rsi, rdi
  mov rdi, FD_STDOUT
  call _write
  ; restore state
  pop rdi
  pop rsi
  pop rdx
  ret

; prints rsi bytes to stderr from the buffer [rdi]
_eprint:
  ; save state
  push rdx
  push rsi
  push rdi
  ; write
  mov rdx, rsi
  mov rsi, rdi
  mov rdi, FD_STDERR
  call _write
  ; restore state
  pop rdi
  pop rsi
  pop rdx
  ret

; prints 1 byte from rsi to the file descriptor rdi
_writechar:
  ; save state
  push rdx
  push rsi
  push rax
  ; write
  mov rax, rsi
  mov rsi, tempchar
  mov [rsi], al
  mov rdx, 1
  call _write
  ; restore state
  pop rax
  pop rsi
  pop rdx
  ret

; prints 1 byte from rdi to stdout
_putchar:
  ; save state
  push rsi
  push rdi
  ; write
  mov rsi, rdi
  mov rdi, FD_STDOUT
  call _writechar
  ; restore state
  pop rdi
  pop rsi
  ret

; prints 1 byte from rdi to stderr
_eputchar:
  ; save state
  push rsi
  push rdi
  ; write
  mov rsi, rdi
  mov rdi, FD_STDERR
  call _writechar
  ; restore state
  pop rdi
  pop rsi
  ret

; prints a line feed to the file descriptor rdi
_writelf:
  ; save state
  push rsi
  ; write
  mov rsi, 10
  call _writechar
  ; restore state
  pop rsi
  ret

; prints a line feed to stdout
_putlf:
  ; save state
  push rdi
  ; write
  mov rdi, FD_STDOUT
  call _writelf
  ; restore state
  pop rdi
  ret

; reads rdx bytes from the file descriptor rdi to the
; buffer [rsi]; the number of bytes read is returned
; in rax
_read:
  ; save state
  push rcx
  push r11
  ; syscall
  mov rax, SYS_READ
  syscall
  ; restore state
  pop r11
  pop rcx
  ret

; reads rsi bytes from stdin into the buffer [rdi]
; the number of bytes read is returned in rax
_input:
  ; save state
  push rdx
  push rsi
  push rdi
  ; read
  mov rdx, rsi
  mov rsi, rdi
  mov rdi, FD_STDIN
  call _read
  ; restore state
  pop rdi
  pop rsi
  pop rdx
  ret

; zeroes out the first rsi bytes of the buffer [rdi]
_zero:
  ; save state
  push rax
  push rcx
  push rdi
  ; zero out
  mov al, 0
  mov rcx, rsi
  rep stosb
  ; restore state
  pop rdi
  pop rcx
  pop rax
  ret

; treats [rdi] as a whole number in base 10 with rsi
; digits, and converts it into a number at rax
_atoi:
  ; save state
  push rdx
  push rbx
  push rcx
  push rdi
  ; convert
  xor rbx, rbx ; index (while rbx < rsi)
  xor rax, rax ; number
  call _atoi_loop
  ; restore state
  pop rdi
  pop rcx
  pop rbx
  pop rdx
  ret

_atoi_loop:
  ; get the character
  xor rcx, rcx
  mov cl, [rdi]
  ; check if it's a valid digit
  cmp cl, 10 ; if newline, number over
  jz _ret ; also if null byte
  je _ret
  cmp cl, '0'
  jl _err_invalid_digit
  cmp cl, '9'
  jg _err_invalid_digit
  ; the math part
  sub cl, '0'
  mov rdx, 10
  mul rdx ; multiplies rax by 10, overflow in rdx (ignored)
  add rax, rcx
  ; continue
  inc rbx
  inc rdi
  cmp rbx, rsi
  jl _atoi_loop
  ret

; conditionally return early
_ret:
  ret

; exits with an error message indicating that the
; digit in rcx is invalid
_err_invalid_digit:
  ; print the left-hand part of the error message
  mov rdi, err_invalid_digitl_s
  mov rsi, err_invalid_digitl_l
  call _eprint
  ; print the digit
  mov rdi, rcx
  call _eputchar
  ; print the right-hand part of the error message
  mov rdi, err_invalid_digitr_s
  mov rsi, err_invalid_digitr_l
  call _eprint
  ; exit with failure
  mov rdi, 1
  call _exit
  ret

; validates the base in rdi, exiting with an error
; message if it is not within the range 2..=36
; [rsi] must be a buffer containing the numeric digits
; of the base, and rdx must be its length
_validate_base:
  cmp rdi, 2
  jl _err_invalid_base
  cmp rdi, 36
  jg _err_invalid_base
  ret

; exits with an error message indicating that the
; base (with digits [rsi] and length rdx) is invalid
; as it does not fall within the required range
_err_invalid_base:
  push rsi
  ; print left-hand part of error message
  mov rdi, err_invalid_basel_s
  mov rsi, err_invalid_basel_l
  call _eprint
  ; print base
  pop rdi
  mov rsi, rdx
  call _eprint
  ; print right-hand part of error message
  mov rdi, err_invalid_baser_s
  mov rsi, err_invalid_baser_l
  call _eprint
  ; exit with failure
  mov rdi, 1
  call _exit
  ret

; converts rdi from base 10 to base rsi, storing the
; digits in [rdx]; [rcx] will be used as an intermediate
; buffer; the length of the converted number is returned
; in rax
_convert_base:
  ; save state
  push rbx
  push rcx
  push rdx
  ; convert
  mov rax, rdi
  call _convert_base_divloop
  mov rdx, [rsp] ; digits array
  mov rbx, [rsp + 8] ; remainders array
  call _convert_base_charsloop
  mov rax, rdx
  pop rdx ; restore + use rdx
  sub rax, rdx ; rax has the length now
  ; restore state
  pop rcx
  pop rbx
  ret

; populates the array at rcx with base rsi digits by
; repeatedly dividing rax by rsi and pushing the remainders
; to the array
_convert_base_divloop:
  xor rdx, rdx ; clear rdx before division
  div rsi
  mov [rcx], dl
  inc rcx
  cmp rax, 0
  jg _convert_base_divloop
  ret

; populates the array at rdx with digits, using the
; elements of the array from rbx to rcx as 1-byte
; remainders from division by a base
_convert_base_charsloop:
  dec rcx
  mov al, [rcx]
  add al, '0'
  cmp al, '9'
  jg _convert_base_charsloop_alph
  jmp _convert_base_charsloop_continue

; adds 'A' - ('9' + 1) to al to ultimately turn
; 10..=35 into A..=Z
_convert_base_charsloop_alph:
  add al, 'A' - ('9' + 1)
  jmp _convert_base_charsloop_continue

; continuation of _convert_base_charsloop
_convert_base_charsloop_continue:
  mov [rdx], al
  inc rdx
  cmp rcx, rbx
  jg _convert_base_charsloop
  ret

; exits with exit code rdi
_exit:
  mov rax, SYS_EXIT
  syscall
  ret