# spriterot
Command line utility to create spritesheets of rotated sprites.

## Usage
````bash
spriterot --help                                                        
spriterot

Usage:
   [options] source

Arguments:
  source           Image to generate the rotations of.

Options:
  -h, --help
  -v, --verbose              Show details about the image(s) being processed.
  -k, --keep-size            Keep the size of the source image for generated rotations, could lead to cropped frames.
  --columns=COLUMNS          Configure the number of columns the generated spritesheet should have. Could lead to wasted space or a cropped spritesheet. Possible values: [min:<number>, max:<number>, clamp:<min>-<max>, <number>]
  --rows=ROWS                Configure the number of rows the generated spritesheet should have. Could lead to wasted space or a cropped spritesheet. Possible values: [min:<number>, max:<number>, clamp:<min>-<max>, <number>]
  --width=WIDTH              Manual width of each generated frame. Could lead to wasted space or cropped frames.
  --height=HEIGHT            Manual height of each generated frame. Could lead to wasted space or cropped frames.
  -m, --margin=MARGIN        Margin around frames, in pixels. Inapplicable when --width or --height are manually set or when --keep-size is enabled. (default: 0)
  -a, --algorithm=ALGORITHM  Algorithm used to rotate the image. Possible values: [rotsprite, shearing, nearest, linear] (default: rotsprite)
  -r, --rotations=ROTATIONS  Amount of rotations to generate.
  -f, --from=FROM            Angle in degrees from which to start generating rotations. (default: 0)
  -t, --to=TO                Angle in degrees up to which to generate rotations. (default: 360)
  -o, --output=OUTPUT        Output filename.
```

## Examples

Create a spritesheet containing 9 frames of `input_image.png`, from 0 to 90 degrees, with a margin of 1 pixel around each frame.
```bash
spriterot -r 9 -f 0 -t 90 -m 1 -o output_image_from_0_to_90.png input_image.png
```

Create a spritesheet containing 20 frames of `input_image.png`, from 0 to 360 degrees, in a 2 columns grid. Verbose output.
```bash
spriterot -v --columns 2 -r 20 -o output_image_from_0_to_90.png input_image.png
```

Create a spritesheet containing 36 frames of `input_image.png`, from 0 to 360 degrees, keeping the size of the original source image for generated frames (could lead to cropped frames).
```bash
spriterot -r 36 --keep-size -o output_image_from_0_to_90.png input_image.png
```