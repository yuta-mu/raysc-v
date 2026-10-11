#include <stdio.h>

int main(){
    const int image_width = 256;
    const int image_height = 256;

    printf("P3\n%d %d \n255\n", image_width, image_height);
    
    for (int j = image_height-1; j>=0; --j) {
        fprintf(stderr, "\rScanlines remaining: %d ", j);
        fflush(stderr);
        for (int i = 0; i < image_width; ++i) {
            int ir = (i * 255) / (image_width - 1);
            int ig = (j * 255) / (image_height - 1);
            int ib = 255 / 4;

            printf("%d %d %d\n", ir, ig, ib);
        }
    }
    fprintf(stderr, "\nDone.\n");
}