BEGIN {
  # get terminal width/height
  "stty size" | getline
  close("stty size")
  terminal["height"] = ($1 ? $1 : 24) * 2
  terminal["width"]  = ($2 ? $2 : 80) * 2

  positive["on"] = 1
  positive["true"] = 1
  positive["yes"] = 1

  negative["off"] = 1
  negative["false"] = 1
  negative["no"] = 1

  # high resolution pixels
  hires["0000"] = " "
  hires["0001"] = "▗"
  hires["0010"] = "▖"
  hires["0011"] = "▄"
  hires["0100"] = "▝"
  hires["0101"] = "▐"
  hires["0110"] = "▞"
  hires["0111"] = "▟"
  hires["1000"] = "▘"
  hires["1001"] = "▚"
  hires["1010"] = "▌"
  hires["1011"] = "▙"
  hires["1100"] = "▀"
  hires["1101"] = "▜"
  hires["1110"] = "▛"
  hires["1111"] = "█"

  ##
  ## Hashmaps to quickly find matching colors and pixels
  ##

  # [1=2] [1=3] [1=4] [2=3] [2=4] [3=4]
  boolpix["111111"] = "\033[38;2;%1$sm" hires["1111"]

  # [1=2] [1=3] [1=4] [2=3] [2=4] [3=4]
  boolpix["000111"] = "\033[38;2;%2$s;48;2;%1$sm" hires["0111"]
  boolpix["011001"] = "\033[38;2;%1$s;48;2;%2$sm" hires["1011"]
  boolpix["101010"] = "\033[38;2;%1$s;48;2;%3$sm" hires["1101"]
  boolpix["110100"] = "\033[38;2;%1$s;48;2;%4$sm" hires["1110"]

  # [1=2] [1=3] [1=4] [2=3] [2=4] [3=4]
  boolpix["001100"] = "\033[38;2;%1$s;48;2;%2$sm" hires["1001"]
  boolpix["010010"] = "\033[38;2;%1$s;48;2;%2$sm" hires["1010"]
  boolpix["100001"] = "\033[38;2;%1$s;48;2;%3$sm" hires["1100"]

  # [1=2] [1=3] [1=4] [2=3] [2=4] [3=4]
  boolpix2["000001"] = "\033[38;2;%3$s;48;2;%5$sm" hires["0011"]
  boolpix2["000010"] = "\033[38;2;%2$s;48;2;%5$sm" hires["0101"]
  boolpix2["000100"] = "\033[38;2;%2$s;48;2;%5$sm" hires["0110"]
  boolpix2["001000"] = "\033[38;2;%1$s;48;2;%5$sm" hires["1001"]
  boolpix2["010000"] = "\033[38;2;%1$s;48;2;%5$sm" hires["1010"]
  boolpix2["100000"] = "\033[38;2;%1$s;48;2;%5$sm" hires["1100"]

  mixtwo["000001"] = "%1$s;%2$s"
  mixtwo["000010"] = "%1$s;%3$s"
  mixtwo["000100"] = "%1$s;%4$s"
  mixtwo["001000"] = "%2$s;%3$s"
  mixtwo["010000"] = "%2$s;%4$s"
  mixtwo["100000"] = "%3$s;%4$s"
}

# clear the terminal
function clrscr() {
  printf("\033[2J")
}

function clamp(val, a, b) { return (val<a) ? a : (val>b) ? b : val }

## get timestamp with one-hundreth of a second precision
function timex() {
  getline <"/proc/uptime"
  close("/proc/uptime")
  return $1
}

# turn cursor on or off
function cursor(state) {
  printf("\033[?25%c", (state in negative) ? "l" : "h")
}

# return index of maximum value of array
#function maxa(arr,   i, val, idx) { for (i in arr) if (arr[i] > val) { idx = i; val = arr[i] }; return idx }
function maxa(arr,   i, val, idx) { for (i in arr) val = (arr[i] > val) ? arr[idx=i] : val; return idx }

# mix colors
function rgbmix(p1, p2, p3,     rgb, n) {
  n = int(split(p1";"p2";"p3, rgb, ";") / 3)
  return sprintf("%d;%d;%d", (rgb[1]+rgb[4]+rgb[7])/n, (rgb[2]+rgb[5]+rgb[8])/n, (rgb[3]+rgb[6]+rgb[9])/n)
}

# convert RGB pixel into brightless value
function rgb2lum(p,    rgb) {
  split(p, rgb, ";")
  return rgb[1] * 0.299 + rgb[2] * 0.587 + rgb[3] * 0.114
}

function clear(dst) { fill(dst, "0;0;0") }

# reset graphic buffer to single color (default black)
function fill(dst, col,   x,y) {
  col = col ? col : "0;0;0"

  for (y=0; y<dst["height"]; y++)
    for (x=0; x<dst["width"]; x++)
      dst[x,y] = col
}

# blend src and dst colors based on alpha channel opacity (srca and dsta)
function blend(src, dst, srca, dsta,    srcrgb, dstrgb, srcperc, dstval, newa, r, g, b) {
  if (srca == 0) return dst
  if (srca == 255) return src

  split(src, srcrgb, ";")
  split(dst, dstrgb, ";")

  srcperc = srca / 255.0
  dstval  = (dsta / 255.0) * (1.0 - srcperc)
  newa    = srcperc + dstval

  r = ((dstrgb[1] * dstval) + (srcrgb[1] * srcperc)) / newa
  g = ((dstrgb[2] * dstval) + (srcrgb[2] * srcperc)) / newa
  b = ((dstrgb[3] * dstval) + (srcrgb[3] * srcperc)) / newa

  return sprintf("%d;%d;%d", r, g, b)
}


# copy graphic buffer to another graphic buffer (with transparency, and edge clipping)
# usage: dst, src, [dstx, dsty, [srcx, srcy, [srcw, srch, [transparent] ] ] ]
function copy(dst, src, dstx, dsty, srcx, srcy, srcw, srch, transp,   dx,dy, dw,dh, sx,sy, sw,sh, x,y, w,h, sa,da, t, pix, xdx,ydy) {
  dw = dst["width"]
  dh = dst["height"]
  sw = src["width"]
  sh = src["height"]

  if ("alpha" in src) sa = src["alpha"]; else sa = 255
  if ("alpha" in dst) da = dst["alpha"]; else da = 255

  dx = int(src["x"])
  dy = int(src["y"])
  sx = 0
  sy = 0
  w = src["width"]
  h = src["height"]

  if (dstx == dstx+0) dx = dstx
  if (dsty == dsty+0) dy = dsty
  if (srcx == srcx+0) sx = srcx
  if (srcy == srcy+0) sy = srcy
  if (srcw == srcw+0) w = ((srcw > 0) && (srcw < src["width"])) ? srcw : w
  if (srch == srch+0) h = ((srch > 0) && (srch < src["height"])) ? srch : h

  if (sprintf("%s", transp)) t = transp
  else if ("transparent" in src) t = src["transparent"]
  else if ("transparent" in glib) t = glib["transparent"]

  for (y=sy; y<(sy+h); y++) {
    # clip image off top/bottom
    if ((dy + y) >= dh) break
    if ((dy + y) < 0) continue

    ydy = y - sy + dy
    for (x=sx; x<(sx+w); x++) {
      pix = src[x,y]
      if ((pix != t) && (pix != "None")) {
        xdx = x - sx + dx

        # clip image on left/right
        if (xdx >= dw) break
        if (xdx < 0) continue

        # draw non-transparent pixel or else background
        #dst[xdx,ydy] = ((pix == t) || (pix == "None")) ? dst[xdx,ydy] : pix
        if ( (sa != 255) || (da != 255) )
          dst[xdx,ydy] = blend(src[x,y], dst[xdx,ydy], sa, da)
        else
          dst[xdx,ydy] = pix
      }
    }
  }
}

## draw image to terminal
function draw(src, xpos, ypos,    w,h, x,y, up,dn, line,screen) {
  w = src["width"]
  h = src["height"]

  # position of zero means center
  if (xpos == 0) xpos = int((terminal["width"] - w) / 4)
  if (ypos == 0) ypos = int((terminal["height"] - h) / 4)

  # negative position means right aligned
  if (xpos < 0) xpos = int((terminal["width"] - w) / 4) + xpos
  if (ypos < 0) ypos = int((terminal["height"] - h) / 4) + ypos

  for (y=0; y<h; y+=2) {
    if (y+ypos > terminal["height"]) break
    if (y+ypos < 0) continue

    prevup = prevdn = -1
    line = sprintf("\033[%0d;%0dH", y/2+ypos+1, xpos+1)
#    for (x=0; x<w; x++) {
    for (x=0; x<w; x+=2) {
      if (x+xpos > terminal["width"]) break
      if (x+xpos < 0) continue

      up = src[x,y+0]
      dn = src[x,y+1]
      if ( (up != prevup) || (dn != prevdn) ) {
        line = line "\033[38;2;" up ";48;2;" dn "m"
        prevup = up
        prevdn = dn
      }
      line = line "▀"
    }
    screen = screen line "\033[0m"
  }
  printf("%s", screen)
}



function drawhi(src, xpos,ypos,     w,h, x,y, pix, d, avgp, maxavgp, i, fgcol,bgcol, group,fg,bg, maxval,maxindx, line, screen) {
  w = src["width"]
  h = src["height"]

  # position of zero means center
  if (xpos == 0) xpos = int((terminal["width"] - w) / 4) + 1
  if (ypos == 0) ypos = int((terminal["height"] - h) / 4) + 1

  # negative position means right aligned
  if (xpos < 0) xpos = int((terminal["width"] - w) / 2) + xpos 
  if (ypos < 0) ypos = int((terminal["height"] - h) / 2) + ypos

  # process all lines
  for (y=0; y<h; y+=2) {
    line = sprintf("\033[%0d;%0dH", ypos+(y/2), xpos)

    # process pixels on line
    for (x=0; x<w; x+=2) {
      # get four pixels from source image
      pix[1] = src[x+0,y+0]
      pix[2] = src[x+1,y+0]
      pix[3] = src[x+0,y+1]
      pix[4] = src[x+1,y+1]

      # 6-bit boolean value representing which pixels are equal
      # (1==2) (1==3) (1==4) (2==3) (2==4) (3==4)
      pixbool = (pix[1]==pix[2]) (pix[1]==pix[3]) (pix[1]==pix[4]) (pix[2]==pix[3]) (pix[2]==pix[4]) (pix[3]==pix[4])

      ## some pixels are equal
 
      # draw colored pixel based on boolean match
      if (pixbool in boolpix) {
        line = line sprintf(boolpix[pixbool], pix[1], pix[2], pix[3], pix[4])
        continue
      }

      # two same + 2 different colors
      if (pixbool in boolpix2) {
        tmp = rgbmix(sprintf(mixtwo[pixbool], pix[1], pix[2], pix[3], pix[4]))
        line = line sprintf(boolpix2[pixbool], pix[1], pix[2], pix[3], pix[4], tmp)
        continue
      }

      ## all four pixels are a different color
 
      # convert RGB to brightness value
      for (i=1; i<=4; i++)
        lum[i] = rgb2lum(pix[i])

      # calculate brightness distance between pixels
      dist[1,2] = dist[2,1] = (lum[2] - lum[1]) ^ 2
      dist[1,3] = dist[3,1] = (lum[3] - lum[1]) ^ 2
      dist[1,4] = dist[4,1] = (lum[4] - lum[1]) ^ 2
      dist[2,3] = dist[3,2] = (lum[3] - lum[2]) ^ 2
      dist[2,4] = dist[4,2] = (lum[4] - lum[2]) ^ 2
      dist[3,4] = dist[4,3] = (lum[4] - lum[3]) ^ 2

      # average brightness distance to other pixels
      avgp[1] = (dist[1,2] + dist[1,3] + dist[1,4]) / 3
      avgp[2] = (dist[2,1] + dist[2,3] + dist[2,4]) / 3
      avgp[3] = (dist[3,1] + dist[3,2] + dist[3,4]) / 3
      avgp[4] = (dist[4,1] + dist[4,2] + dist[4,3]) / 3

      delete bg
      delete fg

      ## pixel farthest from average is bg
      bg[1] = maxa(avgp)
      group[bg[1]] = 0

      ## pixel farthest from bg is fg
      maxval = maxidx = -1
      for (i=1; i<=4; i++) 
	maxval = (dist[bg[1],i] > maxval) ? dist[bg[1],maxidx=i] : maxval
      group[fg[1] = maxidx] = 1


      ## remaining pixels group closest to either bg or 1
      for (i=1; i<=4; i++) {
        if ((i != bg[1]) && (i != fg[1])) {
          if (dist[bg[1],i] > dist[fg[1],i]) {
            group[i] = 1
            fg[length(fg)+1] = i
          } else {
            group[i] = 0
            bg[length(bg)+1] = i
          }
        }
      }


      ## mix fg/bg colors from all pixels in group
      bglen = length(bg)

      if (bglen == 1) {
        fgcol = rgbmix(pix[fg[1]], pix[fg[2]], pix[fg[3]])
        bgcol = pix[bg[1]]
      }
      if (bglen == 2) {
        fgcol = rgbmix(pix[fg[1]], pix[fg[2]])
        bgcol = rgbmix(pix[bg[1]], pix[bg[2]])
      }

      line = line sprintf("\033[38;2;%s;48;2;%sm%s", fgcol, bgcol, hires[group[1] group[2] group[3] group[4]])
    }
    screen = screen line "\033[0m"
  }

  printf("%s", screen)
}

