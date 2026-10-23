#ifndef CORE_IMAGE_H
#define CORE_IMAGE_H

#ifndef RENDER_WIDTH
#define RENDER_WIDTH 64
#endif
#ifndef RENDER_HEIGHT
#define RENDER_HEIGHT 36
#endif

#if RENDER_WIDTH < 1 || RENDER_WIDTH > 32768
#error RENDER_WIDTH must be between 1 and 32768
#endif
#if RENDER_HEIGHT < 1 || RENDER_HEIGHT > 32768
#error RENDER_HEIGHT must be between 1 and 32768
#endif

#endif
