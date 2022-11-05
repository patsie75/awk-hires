BEGIN {
  if ((terminal["width"] < 256) || (terminal["height"] < 72)) {
    printf("Minimum terminal size: %dx%d\n", 128, 36) >"/dev/stderr"
    exit 1
  }

  cursor("off")

  # display number of pictures
  for (i=1; i<6; i++) {
    fname = sprintf("img/landscape%d.xpm", i)
    xpm3load(fname, buf)

    clrscr()
    for (j=0; j<3; j++) {
      draw(buf, 0,0)
      system("sleep 2")
      drawhi(buf, 0,0)
      system("sleep 2")
    }
  }

  cursor("on")
  printf("\n")
}
