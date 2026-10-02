"""
Generate app icons for Not Today app.
Creates a simple, meaningful icon with pause bars and forward arrow.
"""
from PIL import Image, ImageDraw
import os

def create_app_icon(size, output_path):
    """Create app icon with pause bars and forward arrow."""
    # Create image with white background
    img = Image.new('RGB', (size, size), '#FFFFFF')
    draw = ImageDraw.Draw(img)

    # App's sky-blue color
    blue = '#2E7BC4'
    light_blue = '#4A90DA'

    # Scale factors
    scale = size / 1024

    # Draw pause bars (left and right)
    bar_width = int(80 * scale)
    bar_height = int(360 * scale)
    bar_radius = int(40 * scale)
    center_x = size // 2
    center_y = size // 2

    # Left pause bar
    left_x = center_x - int(160 * scale)
    draw.rounded_rectangle(
        [left_x, center_y - bar_height//2,
         left_x + bar_width, center_y + bar_height//2],
        radius=bar_radius,
        fill=blue
    )

    # Right pause bar
    right_x = center_x + int(80 * scale)
    draw.rounded_rectangle(
        [right_x, center_y - bar_height//2,
         right_x + bar_width, center_y + bar_height//2],
        radius=bar_radius,
        fill=blue
    )

    # Forward arrow (suggesting "tomorrow")
    arrow_start_x = center_x + int(200 * scale)
    arrow_y = center_y
    arrow_size = int(60 * scale)

    # Simple right arrow
    arrow_points = [
        (arrow_start_x, arrow_y - arrow_size//2),
        (arrow_start_x + arrow_size, arrow_y),
        (arrow_start_x, arrow_y + arrow_size//2)
    ]
    draw.polygon(arrow_points, fill=light_blue)

    img.save(output_path, 'PNG')
    print(f"Created: {output_path}")

def create_adaptive_foreground(size, output_path):
    """Create adaptive icon foreground (transparent background)."""
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    blue = '#2E7BC4'
    light_blue = '#4A90DA'

    scale = size / 1024

    # Pause bars
    bar_width = int(80 * scale)
    bar_height = int(360 * scale)
    bar_radius = int(40 * scale)
    center_x = size // 2
    center_y = size // 2

    # Left pause bar
    left_x = center_x - int(160 * scale)
    draw.rounded_rectangle(
        [left_x, center_y - bar_height//2,
         left_x + bar_width, center_y + bar_height//2],
        radius=bar_radius,
        fill=blue
    )

    # Right pause bar
    right_x = center_x + int(80 * scale)
    draw.rounded_rectangle(
        [right_x, center_y - bar_height//2,
         right_x + bar_width, center_y + bar_height//2],
        radius=bar_radius,
        fill=blue
    )

    # Forward arrow
    arrow_start_x = center_x + int(200 * scale)
    arrow_y = center_y
    arrow_size = int(60 * scale)

    arrow_points = [
        (arrow_start_x, arrow_y - arrow_size//2),
        (arrow_start_x + arrow_size, arrow_y),
        (arrow_start_x, arrow_y + arrow_size//2)
    ]
    draw.polygon(arrow_points, fill=light_blue)

    img.save(output_path, 'PNG')
    print(f"Created: {output_path}")

if __name__ == "__main__":
    # Create assets directory if it doesn't exist
    os.makedirs('assets/icon', exist_ok=True)

    # Create main app icon (1024x1024)
    create_app_icon(1024, 'assets/icon/app_icon.png')

    # Create adaptive icon foreground (432x432 as recommended)
    create_adaptive_foreground(432, 'assets/icon/app_icon_foreground.png')

    print("\nIcon generation complete!")
    print("Run: flutter pub get")
    print("Then: flutter pub run flutter_launcher_icons")
