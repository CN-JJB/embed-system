extern int not_defined_here(int value);

int needs_external_provider(int value)
{
    return not_defined_here(value);
}
