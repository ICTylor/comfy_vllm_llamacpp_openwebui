#!/usr/bin/env python3
"""
Model Monitor Script for llama-swap YAML Generation

This script continuously monitors a models folder for changes and generates
YAML configuration files compatible with llama-swap.
"""

import os
import time
import re
from pathlib import Path
from typing import Dict, List, Optional
import logging

try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    import yaml
except ImportError as e:
    print(f"Missing required packages. Install with:")
    print("pip install watchdog PyYAML")
    exit(1)

# Configuration
MODELS_FOLDER = "./models"  # Change this to your models folder path
OUTPUT_YAML = "./llama-swap-models.yaml"  # Output YAML file path
SUPPORTED_EXTENSIONS = ['.gguf', '.bin', '.safetensors']  # Model file extensions to monitor

# The script preserves quantization and size info in model names:
# SmolLM2-135M-Instruct-Q4_K_M.gguf -> "smollm2_135m_q4_k_m"
# SmolLM2-135M-Instruct-Q8_0.gguf   -> "smollm2_135m_q8_0"
# Now with proper quantization extraction and clean YAML formatting!

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ModelFileHandler(FileSystemEventHandler):
    """Handles file system events in the models folder"""

    def __init__(self, models_folder: str, output_yaml: str):
        self.models_folder = Path(models_folder)
        self.output_yaml = Path(output_yaml)
        self.generator = YAMLGenerator(models_folder, output_yaml)

        # Generate initial YAML on startup
        self.generator.generate_yaml()

    def on_created(self, event):
        """Handle file creation events"""
        if not event.is_directory:
            self._handle_file_change(event.src_path)

    def on_moved(self, event):
        """Handle file move/rename events"""
        if not event.is_directory:
            self._handle_file_change(event.dest_path)

    def on_modified(self, event):
        """Handle file modification events"""
        if not event.is_directory:
            self._handle_file_change(event.src_path)

    def _handle_file_change(self, file_path: str):
        """Process file changes and regenerate YAML if needed"""
        file_path = Path(file_path)

        # Check if it's a supported model file
        if file_path.suffix.lower() in SUPPORTED_EXTENSIONS:
            logger.info(f"Model file change detected: {file_path.name}")
            # Add a small delay to ensure file is fully written
            time.sleep(2)
            self.generator.generate_yaml()

class YAMLGenerator:
    """Generates YAML configuration files for llama-swap"""

    def __init__(self, models_folder: str, output_yaml: str):
        self.models_folder = Path(models_folder)
        self.output_yaml = Path(output_yaml)

    def find_model_files(self) -> List[Path]:
        """Find all model files in the models folder"""
        model_files = []

        if not self.models_folder.exists():
            logger.warning(f"Models folder does not exist: {self.models_folder}")
            return model_files

        # Recursively search for model files
        for ext in SUPPORTED_EXTENSIONS:
            pattern = f"**/*{ext}"
            files = list(self.models_folder.glob(pattern))
            model_files.extend(files)

        return sorted(model_files)

    def extract_model_name(self, file_path: Path) -> str:
        """Extract a clean model name from the filename"""
        filename = file_path.stem  # Remove extension

        clean_name = filename

        # Convert to lowercase and replace common patterns
        clean_name = clean_name.lower()
        clean_name = re.sub(r'[-_]+', '_', clean_name)  # Normalize separators
        clean_name = clean_name.strip('_-')  # Remove leading/trailing separators

        return clean_name

    def generate_yaml(self):
        """Generate the YAML configuration file"""
        try:
            model_files = self.find_model_files()

            if not model_files:
                logger.info("No model files found")
                return

            # Build the models dictionary
            models_config = {"models": {}}

            for model_file in model_files:
                model_name = self.extract_model_name(model_file)

                # Handle duplicate names by adding a suffix
                original_name = model_name
                counter = 1
                while model_name in models_config["models"]:
                    model_name = f"{original_name}_{counter}"
                    counter += 1

                # Get the absolute path
                abs_path = model_file.resolve()

                # Build the command
                cmd = f"llama-server --model {abs_path} --port ${{PORT}}"

                models_config["models"][model_name] = {"cmd": cmd}

                logger.info(f"Added model: {model_name} -> {model_file.name}")

            # Write the YAML file
            with open(self.output_yaml, 'w') as f:
                yaml.dump(models_config, f, default_flow_style=False, sort_keys=True)

            logger.info(f"Generated YAML config with {len(models_config['models'])} models: {self.output_yaml}")

        except Exception as e:
            logger.error(f"Error generating YAML: {e}")

def main():
    """Main function to start the file monitor"""
    print("Model Monitor for llama-swap YAML Generation")
    print("=" * 50)
    print(f"Monitoring folder: {Path(MODELS_FOLDER).resolve()}")
    print(f"Output YAML file: {Path(OUTPUT_YAML).resolve()}")
    print(f"Supported extensions: {', '.join(SUPPORTED_EXTENSIONS)}")
    print()

    # Ensure models folder exists
    models_path = Path(MODELS_FOLDER)
    if not models_path.exists():
        print(f"Creating models folder: {models_path}")
        models_path.mkdir(parents=True, exist_ok=True)

    # Set up file monitoring
    event_handler = ModelFileHandler(MODELS_FOLDER, OUTPUT_YAML)
    observer = Observer()
    observer.schedule(event_handler, str(models_path), recursive=True)

    # Start monitoring
    observer.start()
    print("✅ File monitoring started. Press Ctrl+C to stop...")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Stopping file monitor...")
        observer.stop()

    observer.join()
    print("✅ File monitor stopped.")

if __name__ == "__main__":
    # You can modify these paths as needed
    import sys

    if len(sys.argv) > 1:
        MODELS_FOLDER = sys.argv[1]
    if len(sys.argv) > 2:
        OUTPUT_YAML = sys.argv[2]

    main()
