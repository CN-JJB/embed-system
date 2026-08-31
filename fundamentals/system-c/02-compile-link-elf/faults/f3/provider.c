/* Deliberately does not include api.h. */
static int exported_reading(void) { return 9; }
int provider_probe(void) { return exported_reading(); }
