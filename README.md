<p align="center">
  <img src="https://user-images.githubusercontent.com/19392104/217358543-1a589bea-9cf0-4922-9b2b-aae28e617820.png">
</p>

# spriterot
Command line utility to create spritesheets of rotated sprites.

## Features
- By default, generates spritesheets wasting as little space as possible.
- 4 rendering algorithms: RotSprite, shearing, nearest, linear.
- Resizes the sprite to make the rotations non-transparent pixels fit just right.
- Configurable (min, max, clamp, exact value) number of rows and columns in the generated spritesheet.
- Configurable number of frames to generate and range of the rotation.
- Overridable width and height for generated frames, or force keeping the same size.
- Configurable margin around generated frames.
- Verbose output to get info about the generated spritesheet.

## Usage
```
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

## Outputs

`rotsprite`: best results for standard pixel art.

![kirby-no-background-table-78-78-rotsprite](https://user-images.githubusercontent.com/19392104/217350096-ef44d493-9c46-4679-8261-d459a098d93d.png)

`shearing`: best results for keeping shades of dither patterns, e.g. Playdate graphics with dithering.

![kirby-no-background-table-78-78-shearing](https://user-images.githubusercontent.com/19392104/217350302-6e57b1df-99ea-4622-98a6-e6de48fbac5a.png)

`nearest`: standard algorithm, nothing special.

![kirby-no-background-table-78-78-nearest](https://user-images.githubusercontent.com/19392104/217350372-274bf2ec-2b1c-45c2-a91f-e67dfc884890.png)

`linear`: best results for conventional graphics, not pixel art. 

![kirby-no-background-table-78-78](https://user-images.githubusercontent.com/19392104/217350403-22f86bd7-24a0-4af2-8d9b-9c14104f8d39.png)
