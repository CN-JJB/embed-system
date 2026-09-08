#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/*
 * P3-M01 Challenge Starter: Minimal ELF Header & Program Header Audit Tool
 *
 * Your goal:
 * Implement the ELF inspection logic to audit unknown binary artifacts
 * and classify each into:
 *   - NOT_ELF
 *   - HOST_OR_NON_ARM
 *   - TARGET_DYNAMIC (print interpreter path)
 *   - TARGET_STATIC
 */

#define EI_NIDENT 16
#define ELFMAG "\177ELF"
#define SELFMAG 4

typedef struct {
    unsigned char e_ident[EI_NIDENT];
    uint16_t      e_type;
    uint16_t      e_machine;
    uint32_t      e_version;
    uint32_t      e_entry;
    uint32_t      e_phoff;
    uint32_t      e_shoff;
    uint32_t      e_flags;
    uint16_t      e_ehsize;
    uint16_t      e_phentsize;
    uint16_t      e_phnum;
    uint16_t      e_shentsize;
    uint16_t      e_shnum;
    uint16_t      e_shstrndx;
} Elf32_Ehdr_Mini;

typedef struct {
    uint32_t p_type;
    uint32_t p_offset;
    uint32_t p_vaddr;
    uint32_t p_paddr;
    uint32_t p_filesz;
    uint32_t p_memsz;
    uint32_t p_flags;
    uint32_t p_align;
} Elf32_Phdr_Mini;

#define PT_DYNAMIC 2
#define PT_INTERP  3
#define EM_ARM     40
#define EM_X86_64 62

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <binary_path>\n", argv[0]);
        return 1;
    }

    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        perror("fopen");
        return 1;
    }

    Elf32_Ehdr_Mini ehdr;
    if (fread(&ehdr, 1, sizeof(ehdr), f) < sizeof(ehdr)) {
        fprintf(stderr, "File too short for ELF header\n");
        fclose(f);
        return 2;
    }

    /*
     * TODO: Task 1 - Verify ELF Magic
     * Check if ehdr.e_ident starts with ELFMAG (\177ELF).
     * If not, print "CLASSIFICATION: NOT_ELF\n", close file, and return 0.
     */

    /*
     * TODO: Task 2 - Inspect Machine Architecture
     * Check ehdr.e_machine.
     * If ehdr.e_machine != EM_ARM (40):
     *   Print "CLASSIFICATION: HOST_OR_NON_ARM\n", close file, and return 0.
     */

    /*
     * TODO: Task 3 - Inspect Program Headers for PT_INTERP
     * If ehdr.e_phoff > 0 and ehdr.e_phnum > 0:
     *   Seek to ehdr.e_phoff.
     *   Iterate through all ehdr.e_phnum headers reading Elf32_Phdr_Mini.
     *   If any phdr.p_type == PT_INTERP:
     *     Seek to phdr.p_offset and read the null-terminated interpreter string.
     *     Mark as dynamic.
     *
     * If PT_INTERP is found:
     *   Print "CLASSIFICATION: TARGET_DYNAMIC\n"
     *   Print "INTERPRETER: <path>\n"
     * Else:
     *   Print "CLASSIFICATION: TARGET_STATIC\n"
     *   Print "INTERPRETER: NONE\n"
     */

    fclose(f);
    return 0;
}
