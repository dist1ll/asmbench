#include <stddef.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <x86intrin.h>

/* vpcmpeqb w/ memory operand */
extern unsigned long v1(char *addr);

int main(int argc, char *argv[]) {

  size_t map_size = ((size_t)1) << 32;
  char *addr = (char *)mmap(0, map_size, PROT_WRITE | PROT_READ,
                            MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

  /* pre-fault all pages */
  for (size_t i = 0; i < map_size; i += 4096) {
    addr[i] = 0xff;
  }
  /* place the needle in the haystack */
  addr[map_size - 4196] = 0x2a;

  unsigned long long min = -1;
  for (size_t i = 0; i < 120; i++) {
    /* START measurement */
    unsigned long long start = __rdtsc();
    unsigned long result = v1(addr);
    unsigned long long end = __rdtsc();
    /* STOP measurement */
    if (end - start < min) {
      min = end - start;
      printf("\n[new min] result: %lu, %llums ", result,
             (end - start) / 1000000);
    } else {
      printf(".");
      fflush(stdout);
    }
  }
  printf("\nminimum: %llums\n", min / 1000000);

  munmap((void *)addr, map_size);
}
