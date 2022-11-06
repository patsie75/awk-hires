# awk-hires
High-resolution graphics in awk

Just to keep things interesting for myself, I dove into using unicode 'QUARTER-BLOCK' characters (four pixels per character) while still only using two colors! I hope you like the results.


In my previous graphics related programs, I used the unicode character 'UPPER-HALF-BLOCK' (U+2580) "▀" to draw pixels. This looks great because of a couple reasons:
 - it has double the resolution of the 'FULL BLOCK' (U+2588) "█" because of an 'upper' and 'lower' part
 - it produces more 'square' pixels in most fonts
 - each part (upper and lower half block) can have its own color
 - it is easy and fast to process drawing two 'lines' in a single pass

But I wanted to look into having even better resolution. I knew about the QUARTER-BLOCK unicode characters and decided to look into using that
 - it would double the horizontal resolution
 - loss of 'squareness' of the pixels
 - how to use only two colors (foreground and background) with four virtual pixels?
 - what would happen to the processing speed?

My most urgent concern was the color issue. Each character in a terminal only has two colors, a foreground color and a background color. This fit perfectly with the two virtual pixels in the HALF-BLOCK characters, but how to display four pixels with only two colors?
I could just pick two colors out of the four pixels and use those (i.e. always the top and bottom left pixel colors), but that would result in pretty much the same result as the HALF-BLOCK character. It needed to be more dynamic than that.

I came up with the following idea:
 - convert the RGB of all four virtual pixels into luminance (brightness) values
 - calculate the distances between all four luminance values and determine the furthest outlier (the luminance/color which is most off from the rest)
 - put this pixel in the group 'background color'
 - find the luminance of the pixel furthest from th pixel found in the previous steps. This is the 'most opposite' pixel color from the first
 - put this second pixel in the group 'foreground color'
 - calculate the distances of the remaining two pixel to both the foreground and background pixels and put them in the group which they are closest to

The RGB to Luminance formula I found on the internet states: Lum = R * 0.299 + G * 0.587 + B * 0.114
 
Example:
 +-----+-----+     +-----+-----+   dist[1->2] = 3.0
 |  1  |  2  |     |  1  |  2  |   dist[1->3] = 0.1
 | blk | red |     | 0.0 | 3.0 |   dist[1->4] = 8.8
 +-----+-----+  >  +-----+-----+   dist[2->3] = 2.9
 |  3  |  4  |     |  3  |  4  |   dist[2->4] = 5.8
 | blu | yel |     | 0.1 | 8.8 |   dist[3->4] = 8.7
 +-----+-----+     +-----+-----+

So pixel 4 (yellow) is the furthest from the others and gets assigned into pixelgroup 'background'
Pixel 1 (black) is has the furthest distance from pixel 4, and thus gets assigned to pixelgroup 'foreground'
Both pixels 2 and 3 are closer to pixel 1 than to pixel 4, so both get also assigned to pixelgroup 'foreground'

 +-----+-----+     +-----+-----+
 |  1  |  2  |     | ███ | ███ |
 | fgr | fgr |     | ███ | ███ |
 +-----+-----+  >  +-----+-----+
 |  3  |  4  |     | ███ |     |
 | fgr | bgr |     | ███ |     |
 +-----+-----+     +-----+-----+

So now we have our unicode character for the shape, but what about the colors?

well, the background color should be easy, there is only one pixel in that group, so it will be that color (yellow)
The remaining pixels need to be mixed into a color, so we add the RGB values of those pixels together and average them

 - [1] Black ==   0;  0;  0
 - [2] Red   == 255;  0;  0
 - [3] Blue  ==   0;  0;255 +
                -------------
                255;  0;255  / 3  = 85;0;85

So the background color will be: 85;0;85 or #550055


The above example with four differently colored pixels is the worst case scenario (performance wise) to calculate.
So we would like to stay away from that as much as we can to get better performance out of our program.
Luckily there are some easy to calculate pixel/color orders.

 - If all four pixels are the same color, pick that color as foreground and draw a FULL-BLOCK
 - If three pixels are the same color, then one pixel is different. Meaning we still only have two colors and thus no calculations to perform
 - If there are two and two the same pixels, still only two colors!
 - If there are two the same and two different pixels. pick the matching colors as foreground and mix the two remaining to an average

These four scenarios handle about one third of most full colour pictures that I've tested with and can have some significant performance benefit to leverage. With some hashmap trickery in the code, we can avoid writing out long if/then/elseif/elseif/elseif/fi statements and do a single hashmap lookup to print the foureground/background colors and matching unicode character

```
    ## 6 boolean values representing if pixels have the same color
    # the order of the boolean values: 1==2 1==3 1==4 2==3 2==4 3==4

    # all four pixels are the same
    boolpix["111111"] = "\033[38;2;%1$sm" hires["1111"]

    # example of 3 pixels that have the same value (pixel 2, 3 and 4)
    boolpix["000111"] = "\033[38;2;%2$s;48;2;%1$sm" hires["0111"]

    # example of 2 and 2 the same colored pixels (1==4 and 2==3)
    boolpix["001100"] = "\033[38;2;%1$s;48;2;%2$sm" hires["1001"]
```

and with a single sprintf() we can add the colors and unicode character to a 'line'
```
    # 6-bit boolean value representing which pixels are equal
    pixbool = (pix[1]==pix[2]) (pix[1]==pix[3]) (pix[1]==pix[4]) (pix[2]==pix[3]) (pix[2]==pix[4]) (pix[3]==pix[4])

    if (pixbool in boolpix) {
      line = line sprintf(boolpix[pixbool], pix[1], pix[2], pix[3], pix[4])
      continue
    }
```

Any leftover color combinations (four different colored pixels) need to be handled by the first mentioned process

An example of how this looks like, compared to the old '2 pixel' resolution:


https://user-images.githubusercontent.com/32614987/200144651-7d8a33f3-9592-4e60-a669-fabee1602a67.mp4


(Better quality version at: https://youtu.be/WLVDlwVeP9M)
