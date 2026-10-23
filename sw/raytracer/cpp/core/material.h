#ifndef CORE_MATERIAL_H
#define CORE_MATERIAL_H

#include "vec3.h"
#include <stdbool.h>

typedef struct {
    vec3 albedo;
    bool is_mirror;
}material;

#endif