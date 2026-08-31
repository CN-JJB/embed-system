/* Deliberately does not include sampler.h so the linkage bug reaches link time. */
int sample_limit = 4;
int sample_dropped;
static int running_total;
static int sampler_scale(int value) { return value * 2; }
void sampler_record(int value)
{
    if (value > sample_limit) { ++sample_dropped; return; }
    running_total += sampler_scale(value);
}
int sampler_total(void) { return running_total; }
