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
import gc
import traceback
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
        self.max_input_dimension = self.config.getint('ImageProcessing', 'max_input_dimension', fallback=4000)

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

    def _get_memory_info(self):
        """
        Get current memory usage information.

        Returns:
            dict: Memory info with 'available_mb' and 'total_mb' keys, or None if unavailable
        """
        try:
            # Read /proc/meminfo to get memory stats (Linux only)
            with open('/proc/meminfo', 'r') as f:
                meminfo = {}
                for line in f:
                    parts = line.split(':')
                    if len(parts) == 2:
                        key = parts[0].strip()
                        # Extract number from value (e.g., "1234 kB" -> 1234)
                        value_str = parts[1].strip().split()[0]
                        meminfo[key] = int(value_str)

                # Calculate available memory in MB
                # MemAvailable is the best indicator (includes reclaimable cache)
                available_kb = meminfo.get('MemAvailable', meminfo.get('MemFree', 0))
                total_kb = meminfo.get('MemTotal', 0)

                return {
                    'available_mb': available_kb / 1024,
                    'total_mb': total_kb / 1024,
                    'available_percent': (available_kb / total_kb * 100) if total_kb > 0 else 0
                }
        except Exception as e:
            logging.debug(f"Could not read memory info: {e}")
            return None

    def _validate_image_file(self, file_path):
        """
        Validate that a file is readable and a valid image.

        Args:
            file_path: Path to the file to validate

        Returns:
            tuple: (is_valid, error_message)
        """
        # Check if file exists and is readable
        if not file_path.exists():
            return False, f"File does not exist: {file_path}"

        if not file_path.is_file():
            return False, f"Path is not a file: {file_path}"

        if not os.access(file_path, os.R_OK):
            return False, f"File is not readable: {file_path}"

        # Check file size
        try:
            file_size = file_path.stat().st_size
            if file_size == 0:
                return False, f"File is empty (0 bytes)"

            # Log file size for diagnostics
            size_mb = file_size / (1024 * 1024)
            logging.debug(f"File size: {size_mb:.2f} MB")
        except Exception as e:
            return False, f"Could not read file size: {e}"

        # Try to open the image file to validate it's a valid image
        try:
            with Image.open(file_path) as img:
                # Try to load image data to catch truncated/corrupted files
                img.verify()
            return True, None
        except Exception as e:
            return False, f"Invalid or corrupted image file: {str(e)}"

    def _downsample_if_needed(self, img):
        """
        Downsample image if either dimension exceeds max_input_dimension.
        This prevents out-of-memory errors on low-RAM devices.

        Args:
            img: PIL Image object

        Returns:
            PIL Image object (either original or downsampled copy)
        """
        # Check if downsampling is disabled
        if self.max_input_dimension <= 0:
            return img

        # Check if image exceeds maximum dimension
        max_dim = max(img.width, img.height)
        if max_dim <= self.max_input_dimension:
            # Image is within limits
            return img

        # Calculate new dimensions maintaining aspect ratio
        if img.width > img.height:
            # Landscape or square
            new_width = self.max_input_dimension
            new_height = int(img.height * (self.max_input_dimension / img.width))
        else:
            # Portrait
            new_height = self.max_input_dimension
            new_width = int(img.width * (self.max_input_dimension / img.height))

        logging.warning(f"Large image detected ({img.width}x{img.height}), downsampling to ({new_width}x{new_height}) "
                       f"to prevent memory exhaustion")

        # Downsample using high-quality LANCZOS resampling
        downsampled = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

        return downsampled

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

            # Step 1: Validate file before processing
            is_valid, error_msg = self._validate_image_file(raw_path)
            if not is_valid:
                logging.error(f"Validation failed for {raw_path.name}: {error_msg}")
                return False

            # Step 2: Check memory before processing
            mem_before = self._get_memory_info()
            if mem_before:
                logging.info(f"Memory before processing: {mem_before['available_mb']:.1f} MB available "
                           f"({mem_before['available_percent']:.1f}% of {mem_before['total_mb']:.0f} MB)")

                # Warn if memory is low (less than 100MB available)
                if mem_before['available_mb'] < 100:
                    logging.warning(f"LOW MEMORY: Only {mem_before['available_mb']:.1f} MB available. "
                                  f"Processing may fail or cause OOM kill.")

            # Step 3: Open and process image
            # Note: We need to reopen after verify() because verify() invalidates the image
            with Image.open(raw_path) as img:
                # Log image dimensions
                logging.info(f"Image dimensions: {img.width}x{img.height}, mode: {img.mode}")

                # Convert to RGB if needed (handles RGBA, P, etc.)
                if img.mode not in ('RGB', 'L'):
                    logging.debug(f"Converting from {img.mode} to RGB")
                    img = img.convert('RGB')

                # Auto-rotate based on EXIF orientation
                img = ImageOps.exif_transpose(img)

                # Downsample if image is too large (prevents OOM on low-RAM devices)
                img = self._downsample_if_needed(img)

                # Choose processing strategy based on orientation
                if self.is_landscape(img):
                    processed = self.process_landscape(img)
                else:
                    processed = self.process_portrait(img)

                # Step 4: Save processed image
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

            # Step 5: Check memory after processing
            mem_after = self._get_memory_info()
            if mem_after and mem_before:
                mem_used = mem_before['available_mb'] - mem_after['available_mb']
                logging.info(f"Memory after processing: {mem_after['available_mb']:.1f} MB available "
                           f"(used {mem_used:.1f} MB for this image)")

            return True

        except MemoryError as e:
            logging.error(f"OUT OF MEMORY while processing {raw_path.name}")
            logging.error(f"Error details: {str(e)}")
            logging.error("Traceback:\n" + traceback.format_exc())
            return False
        except IOError as e:
            logging.error(f"I/O ERROR while processing {raw_path.name}: {str(e)}")
            logging.error("Traceback:\n" + traceback.format_exc())
            return False
        except OSError as e:
            logging.error(f"OS ERROR while processing {raw_path.name}: {str(e)}")
            logging.error("Traceback:\n" + traceback.format_exc())
            return False
        except Exception as e:
            logging.error(f"UNEXPECTED ERROR while processing {raw_path.name}: {str(e)}")
            logging.error(f"Error type: {type(e).__name__}")
            logging.error("Traceback:\n" + traceback.format_exc())
            return False

    def cleanup_orphaned_photos(self):
        """Remove processed photos that no longer have corresponding raw photos."""
        if not self.processed_dir.exists():
            return

        # Supported image extensions for raw photos
        image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.heic'}

        # Get stems of all raw photos (filename without extension)
        raw_stems = {
            f.stem for f in self.raw_dir.iterdir()
            if f.is_file() and f.suffix.lower() in image_extensions
        } if self.raw_dir.exists() else set()

        # Check each processed photo
        deleted_count = 0
        for processed_file in self.processed_dir.iterdir():
            if not processed_file.is_file():
                continue

            # Check if corresponding raw photo exists (using stem for matching)
            if processed_file.stem not in raw_stems:
                # Orphaned processed photo - delete it
                logging.info(f"Removing orphaned processed photo: {processed_file.name}")
                try:
                    processed_file.unlink()
                    deleted_count += 1
                except Exception as e:
                    logging.error(f"Failed to delete {processed_file.name}: {e}")

        if deleted_count > 0:
            logging.info(f"Cleanup complete: {deleted_count} orphaned photo(s) removed")
        else:
            logging.debug("No orphaned photos found")

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

        total_images = len(image_files)
        logging.info(f"Found {total_images} images to process")

        # Get list of already processed files
        processed_files = {f.stem for f in self.processed_dir.iterdir() if f.is_file()}

        success_count = 0
        skip_count = 0
        fail_count = 0
        current_index = 0

        # Log initial memory state
        initial_mem = self._get_memory_info()
        if initial_mem:
            logging.info(f"Initial memory state: {initial_mem['available_mb']:.1f} MB available "
                       f"({initial_mem['available_percent']:.1f}% of {initial_mem['total_mb']:.0f} MB)")

        for image_file in image_files:
            current_index += 1

            # Skip if already processed (check stem to handle format conversions)
            if image_file.stem in processed_files:
                logging.info(f"[{current_index}/{total_images}] Skipping already processed: {image_file.name}")
                skip_count += 1
                continue

            # Log progress
            logging.info(f"[{current_index}/{total_images}] Starting to process: {image_file.name}")

            # Process the image
            if self.process_image(image_file):
                success_count += 1
                logging.info(f"[{current_index}/{total_images}] Successfully processed: {image_file.name}")
            else:
                fail_count += 1
                logging.error(f"[{current_index}/{total_images}] Failed to process: {image_file.name}")

            # Force garbage collection after each image to free memory
            # This is especially important on low-memory devices like Pi Zero 2 W
            if current_index < total_images:  # Don't log on last iteration
                gc.collect()
                mem_after_gc = self._get_memory_info()
                if mem_after_gc:
                    logging.debug(f"After garbage collection: {mem_after_gc['available_mb']:.1f} MB available")

        # Final summary
        logging.info("=" * 60)
        logging.info(f"Processing complete: {success_count} processed, {skip_count} skipped, {fail_count} failed")

        # Highlight discrepancies
        expected_to_process = total_images - skip_count
        actually_processed = success_count + fail_count
        if actually_processed < expected_to_process:
            logging.warning(f"DISCREPANCY DETECTED: Expected to process {expected_to_process} images, "
                          f"but only attempted {actually_processed}. "
                          f"This suggests the script may have been interrupted or killed.")

        # Log final memory state
        final_mem = self._get_memory_info()
        if final_mem and initial_mem:
            mem_change = initial_mem['available_mb'] - final_mem['available_mb']
            logging.info(f"Final memory state: {final_mem['available_mb']:.1f} MB available "
                       f"(net change: {mem_change:+.1f} MB)")

        logging.info("=" * 60)

        # Cleanup orphaned processed photos (photos deleted from Dropbox)
        self.cleanup_orphaned_photos()


def main():
    """Main entry point."""
    # Allow config path as command line argument
    config_path = sys.argv[1] if len(sys.argv) > 1 else "/home/pi/photoframe/photoframe_config.ini"

    processor = PhotoFrameProcessor(config_path)
    processor.process_all()


if __name__ == "__main__":
    main()
