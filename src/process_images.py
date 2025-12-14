#!/usr/bin/env python3
"""
Raspberry Pi Photo Frame - Image Processor
Processes raw photos for display on the photo frame with optimal aesthetics.

Handles two strategies:
- Landscape photos: Strict crop to fill screen
- Portrait photos: Blurred background composite to avoid subject cropping
"""

import os
import sys
from pathlib import Path
from configparser import ConfigParser
from PIL import Image, ImageFilter, ImageOps
import logging


class PhotoFrameProcessor:
    """Processes images for the photo frame display."""

    def __init__(self, config_path="/home/pi/photoframe/photoframe_config.ini"):
        """Initialize processor with configuration."""
        self.config = ConfigParser()

        # Try to load config from multiple locations
        config_locations = [
            config_path,
            Path(__file__).parent.parent / "photoframe_config.ini",
            Path.cwd() / "photoframe_config.ini"
        ]

        config_loaded = False
        for location in config_locations:
            if Path(location).exists():
                self.config.read(location)
                config_loaded = True
                print(f"Loaded configuration from: {location}")
                break

        if not config_loaded:
            print("ERROR: Could not find photoframe_config.ini")
            sys.exit(1)

        # Load configuration values
        self.screen_width = self.config.getint('Display', 'screen_width')
        self.screen_height = self.config.getint('Display', 'screen_height')
        self.blur_radius = self.config.getint('ImageProcessing', 'blur_radius')
        self.jpeg_quality = self.config.getint('ImageProcessing', 'jpeg_quality')
        self.resampling_str = self.config.get('ImageProcessing', 'resampling')

        # Map resampling string to Pillow constant
        resampling_map = {
            'LANCZOS': Image.Resampling.LANCZOS,
            'BILINEAR': Image.Resampling.BILINEAR,
            'BICUBIC': Image.Resampling.BICUBIC
        }
        self.resampling = resampling_map.get(self.resampling_str, Image.Resampling.LANCZOS)

        self.output_size = (self.screen_width, self.screen_height)

        # Paths
        self.raw_dir = Path(self.config.get('Paths', 'raw_photos_dir'))
        self.processed_dir = Path(self.config.get('Paths', 'processed_photos_dir'))
        self.log_file = Path(self.config.get('Paths', 'log_file'))

        # Setup logging
        self._setup_logging()

        # Ensure output directory exists
        self.processed_dir.mkdir(parents=True, exist_ok=True)

        logging.info(f"Processor initialized: {self.screen_width}x{self.screen_height}")
        logging.info(f"Raw dir: {self.raw_dir}")
        logging.info(f"Processed dir: {self.processed_dir}")

    def _setup_logging(self):
        """Configure logging to file and console."""
        # Ensure log directory exists
        self.log_file.parent.mkdir(parents=True, exist_ok=True)

        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )

    def is_landscape(self, img):
        """Check if image is landscape orientation."""
        return img.width >= img.height

    def process_landscape(self, img):
        """
        Process landscape photo with strict crop strategy.
        Fills entire screen, cropping as needed for Ken Burns effect.
        """
        logging.info(f"Processing as landscape: {img.width}x{img.height}")

        # Use ImageOps.fit to scale and crop to exact output size
        processed = ImageOps.fit(
            img,
            self.output_size,
            method=self.resampling,
            centering=(0.5, 0.5)
        )

        return processed

    def process_portrait(self, img):
        """
        Process portrait photo with blurred background strategy.
        Prevents subject cropping and eliminates black bars.
        """
        logging.info(f"Processing as portrait: {img.width}x{img.height}")

        # Step 1: Create blurred background
        blurred_bg = img.copy()
        blurred_bg = blurred_bg.filter(ImageFilter.GaussianBlur(radius=self.blur_radius))

        # Crop blurred background to screen size
        blurred_bg = ImageOps.fit(
            blurred_bg,
            self.output_size,
            method=self.resampling,
            centering=(0.5, 0.5)
        )

        # Step 2: Scale original photo to fit screen height while maintaining aspect ratio
        # Calculate scaling to fit height
        scale_factor = self.screen_height / img.height
        new_width = int(img.width * scale_factor)
        new_height = self.screen_height

        # Ensure we don't exceed screen width
        if new_width > self.screen_width:
            scale_factor = self.screen_width / img.width
            new_width = self.screen_width
            new_height = int(img.height * scale_factor)

        scaled_original = img.resize((new_width, new_height), self.resampling)

        # Step 3: Composite - paste scaled original centered on blurred background
        canvas = blurred_bg.copy()

        # Calculate position to center the scaled image
        x_offset = (self.screen_width - new_width) // 2
        y_offset = (self.screen_height - new_height) // 2

        canvas.paste(scaled_original, (x_offset, y_offset))

        return canvas

    def process_image(self, raw_path):
        """
        Process a single image file.

        Args:
            raw_path: Path to raw input image

        Returns:
            bool: True if successful, False otherwise
        """
        try:
            logging.info(f"Processing: {raw_path.name}")

            # Open and handle EXIF orientation
            with Image.open(raw_path) as img:
                # Convert to RGB if needed (handles RGBA, P, etc.)
                if img.mode not in ('RGB', 'L'):
                    img = img.convert('RGB')

                # Auto-rotate based on EXIF orientation
                img = ImageOps.exif_transpose(img)

                # Choose processing strategy based on orientation
                if self.is_landscape(img):
                    processed = self.process_landscape(img)
                else:
                    processed = self.process_portrait(img)

                # Save processed image
                output_path = self.processed_dir / raw_path.name

                # Convert to JPG if not already
                if output_path.suffix.lower() in ['.png', '.bmp', '.gif', '.tiff']:
                    output_path = output_path.with_suffix('.jpg')

                processed.save(
                    output_path,
                    'JPEG',
                    quality=self.jpeg_quality,
                    optimize=True
                )

                logging.info(f"Saved: {output_path.name} ({self.screen_width}x{self.screen_height})")
                return True

        except Exception as e:
            logging.error(f"Failed to process {raw_path.name}: {str(e)}")
            return False

    def process_all(self):
        """Process all images in the raw directory."""
        if not self.raw_dir.exists():
            logging.error(f"Raw photos directory does not exist: {self.raw_dir}")
            return

        # Supported image extensions
        image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.heic'}

        # Get all image files
        image_files = [
            f for f in self.raw_dir.iterdir()
            if f.is_file() and f.suffix.lower() in image_extensions
        ]

        if not image_files:
            logging.info("No images found to process")
            return

        logging.info(f"Found {len(image_files)} images to process")

        # Get list of already processed files
        processed_files = {f.stem for f in self.processed_dir.iterdir() if f.is_file()}

        success_count = 0
        skip_count = 0
        fail_count = 0

        for image_file in image_files:
            # Skip if already processed (check stem to handle format conversions)
            if image_file.stem in processed_files:
                logging.debug(f"Skipping already processed: {image_file.name}")
                skip_count += 1
                continue

            if self.process_image(image_file):
                success_count += 1
            else:
                fail_count += 1

        logging.info(f"Processing complete: {success_count} processed, {skip_count} skipped, {fail_count} failed")


def main():
    """Main entry point."""
    # Allow config path as command line argument
    config_path = sys.argv[1] if len(sys.argv) > 1 else "/home/pi/photoframe/photoframe_config.ini"

    processor = PhotoFrameProcessor(config_path)
    processor.process_all()


if __name__ == "__main__":
    main()
