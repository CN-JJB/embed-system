#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/*
 * Reference Solution: Minimal ELF32/64 header inspection tool
 * Used by reviewer to validate candidate classification without leaks.
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

#define PT_INTERP 3
#define PT_DYNAMIC 2
#define EM_ARM 40
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

    if (memcmp(ehdr.e_ident, ELFMAG, SELFMAG) != 0) {
        printf("CLASSIFICATION: NOT_ELF\n");
        fclose(f);
        return 0;
    }

    int is_arm = (ehdr.e_machine == EM_ARM);
    int is_x86_64 = (ehdr.e_machine == EM_X86_64);

    if (!is_arm) {
        printf("CLASSIFICATION: HOST_OR_NON_ARM (Machine: %u, %s)\n",
               ehdr.e_machine, is_x86_64 ? "x86_64" : "other");
        fclose(f);
        return 0;
    }

    /* Inspect program headers for ARM ELF */
    int has_interp = 0;
    char interp_buf[256] = {0};

    if (ehdr.e_phoff > 0 && ehdr.e_phnum > 0) {
        fseek(f, ehdr.e_phoff, SEEK_SET);
        for (int i = 0; i < ehdr.e_phnum; i++) {
            Elf32_Phdr_Mini phdr;
            if (fread(&phdr, 1, sizeof(phdr), f) < sizeof(phdr)) break;
            if (phdr.p_type == PT_INTERP) {
                has_interp = 1;
                long cur = ftell(f);
                fseek(f, phdr.p_offset, SEEK_SET);
                size_t to_read = phdr.p_filesz < sizeof(interp_buf)-1 ? phdr.p_filesz : sizeof(interp_buf)-1;
                if (fread(interp_buf, 1, to_read, f) > 0) {
                    interp_buf[to_read] = '\0';
                }
                fseek(f, cur, SEEK_SET);
            }
        }
    }

    fclose(f);

    if (has_interp) {
        printf("CLASSIFICATION: TARGET_DYNAMIC\n");
        printf("INTERPRETER: %s\n", interp_buf);
    } else {
        printf("CLASSIFICATION: TARGET_STATIC\n");
        printf("INTERPRETER: NONE\n");
    }

    return 0;
}
