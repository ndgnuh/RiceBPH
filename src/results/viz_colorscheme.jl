# Hybrid from terminal.sexy
const COLORSCHEME = (;
   foreground = colorant"#c5c8c6",
   background = colorant"#1d1f21",
   cursorColor = colorant"#c5c8c6",

   # black
   color0 = colorant"#282a2e",
   color8 = colorant"#373b41",

   # red
   color1 = colorant"#a54242",
   color9 = colorant"#cc6666",

   # green
   color2 = colorant"#8c9440",
   color10 = colorant"#b5bd68",

   # yellow
   color3 = colorant"#de935f",
   color11 = colorant"#f0c674",

   # blue
   color4 = colorant"#5f819d",
   color12 = colorant"#81a2be",

   # magenta
   color5 = colorant"#85678f",
   color13 = colorant"#b294bb",

   # cyan
   color6 = colorant"#5e8d87",
   color14 = colorant"#8abeb7",

   # white
   color7 = colorant"#707880",
   color15 = colorant"#c5c8c6",
)

const COLORSCHEME2 = let diff = 45
   palette = mapreduce(hcat, 0:diff:(360-diff)) do hue
      sequential_palette(hue, 5; b = 0.5)[(begin+1):(end-1)]
   end
   transpose(palette)[:]
end
