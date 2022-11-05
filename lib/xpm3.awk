BEGIN {
  # generate color pallet
  cmd = "convert -list color 2>/dev/null"
  while ((cmd | getline) > 0)
    #if ( match($2, /srgb\(([0-9]+),([0-9]+),([0-9]+)\)/, arr) )
    if ( $2 ~ /srgb\(([0-9]+),([0-9]+),([0-9]+)\)/ ) {
      gsub(/srgb\(|\)/, "", $2)
      split($2, arr, ",");
      pallet[$1] = sprintf("%d;%d;%d", arr[1], arr[2], arr[3])
    }
  close(cmd)
}

# convert hexadecimal string to decimal
function hex(str,    hexstr, s, h, dec) {
  hexstr = "0123456789abcdef"

  s = tolower(str)
  if (s ~ /^0x/) s = substr(s, 3)

  while (s) {
    h = substr(s, 1, 1)
    s = substr(s, 2)

    dec *= 16
    dec += index(hexstr, h) - 1
  }
  return dec
}

function xpm3load(fname, dst,    a, width, height, numcols, charsppx, color, c, data, i, j, line, pix, linenr) {
  while ((getline <fname) > 0) {
    # ignore comments
    if ($1 == "/*")
      continue

    # read width, height, colors and characters per pixel
    #if ( match($0, /"([0-9]+)\s+([0-9]+)\s+([0-9]+)\s+([0-9]+)\s*"/, a) ) {
    if ($0 ~ /"([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) *"/) {
      gsub(/[,"]/, "", $0)
      width    = int($1)
      height   = int($2)
      numcols  = int($3)
      charsppx = int($4)
      continue
    }

    # map chars to colors
    #if ( match($0, /"(.+) c ([^"]+)",/, a) ) {
    if ($0 ~ /"(..) c ([^" ]+)",/) {
      gsub(/^"|",?$/, "", $0)
      col = substr($0, 1, charsppx)
      cname = substr($0, charsppx+4)
      if (cname in pallet) {
        color[col] = pallet[cname]
      } else {
        #if ( match(a[2], /#(..)(..)(..)/, c) )
        if (cname ~ /#(..)(..)(..)/ ) {
          c[1] = substr(cname, 2,2)
          c[2] = substr(cname, 4,2)
          c[3] = substr(cname, 6,2)
          color[col] = hex(c[1]) ";" hex(c[2]) ";" hex(c[3])
        } else color[col] = cname
      }
      continue
    }

    # get pixel data
    if ( $0 ~ /^".+",?$/ ) {
      gsub(/^"|",?$/, "", $0)
      data[linenr++] = $0
    } 
  }

  close(fname)

  # convert pixel data to colors
  for (j=0; j<height; j++) {
    line = data[j]
    for (i=0; i<width; i++) {
      pix = substr(line, (i*charsppx)+1, charsppx)
      if (pix in color) {
        dst[i,j] = color[pix]
      } else {
        printf("xpm3::load(): Could not find color \"%s\" in color[] on line #%d (pos %d)\n", pix, j, i)
        return 0
      }
    }
  }

  dst["width"]  = width
  dst["height"] = height

  return 1
}
