#include <stdio.h>
#include <string.h>

struct user {
    int id;
    const char *name;
};

static const struct user *find_user(const struct user *users, size_t n, int id)
{
    for (size_t i = 0; i < n; ++i) {
        if (users[i].id == id) {
            return &users[i];
        }
    }
    return NULL;
}

static void print_user(const struct user *users, size_t n, int id)
{
    const struct user *u = find_user(users, n, id);
    printf("user %d name=%s len=%zu\n", id, u->name, strlen(u->name));
}

int main(void)
{
    const struct user users[] = {
        {1, "Ada"},
        {2, "Linus"},
        {3, "Ken"},
    };

    print_user(users, sizeof users / sizeof users[0], 7);
    return 0;
}
