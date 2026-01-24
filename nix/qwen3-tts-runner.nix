# Qwen3-TTS runner using VoiceDesign model
# Uses PyTorch nightly with CUDA 12.8 (has Blackwell SM120 support)
#
# Usage: nix run .#qwen3-tts -- script.py
#        nix run .#qwen3-tts -- --text "Hello world" --instruct "cheerful female voice"
{
  lib,
  stdenv,
  writeShellApplication,
  python312,
  ffmpeg,
  sox,
  cuda,
}:

let
  python = python312.withPackages (ps: with ps; [ pip virtualenv ]);

  quickGenScript = ''
#!/usr/bin/env python3
"""
Quick Qwen3-TTS generation from command line.
For more complex scripts, pass a .py file as argument.
"""
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="Qwen3-TTS Voice Generation")
    parser.add_argument("--text", "-t", type=str, required=True,
                        help="Text to synthesize")
    parser.add_argument("--instruct", "-i", type=str, default="",
                        help="Voice description/instruction for VoiceDesign model")
    parser.add_argument("--language", "-l", type=str, default="English",
                        help="Language (English, Chinese, Japanese, Korean, etc.)")
    parser.add_argument("--output", "-o", type=str, default="output.wav",
                        help="Output WAV file path")
    parser.add_argument("--model", "-m", type=str, 
                        default="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
                        help="Model to use")
    args = parser.parse_args()

    import torch
    import soundfile as sf
    from qwen_tts import Qwen3TTSModel

    print(f"Loading {args.model}...", file=sys.stderr)
    
    model = Qwen3TTSModel.from_pretrained(
        args.model,
        device_map="cuda:0",
        dtype=torch.bfloat16,
    )
    
    print("Generating audio...", file=sys.stderr)
    
    wavs, sr = model.generate_voice_design(
        text=args.text,
        language=args.language,
        instruct=args.instruct,
    )
    
    sf.write(args.output, wavs[0], sr)
    print(f"Saved to {args.output}", file=sys.stderr)

if __name__ == "__main__":
    main()
'';

  quickGenScriptFile = builtins.toFile "qwen3_tts_quick.py" quickGenScript;

in
writeShellApplication {
  name = "qwen3-tts";
  
  runtimeInputs = [ python ffmpeg sox ];
  
  text = ''
    # Create venv with PyTorch nightly (has SM120/Blackwell support)
    VENV_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/qwen3-tts-nightly"
    
    setup_venv() {
      echo "Setting up Qwen3-TTS with PyTorch nightly (Blackwell SM120)..." >&2
      echo "This will download ~3GB on first run..." >&2
      rm -rf "$VENV_DIR"
      ${python}/bin/python -m venv "$VENV_DIR"
      "$VENV_DIR/bin/pip" install --quiet --upgrade pip wheel
      # Install PyTorch nightly with CUDA 12.8 (has SM120 support)
      "$VENV_DIR/bin/pip" install --quiet --pre torch torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu128
      # Install qwen-tts and deps
      "$VENV_DIR/bin/pip" install --quiet qwen-tts soundfile
      echo "Setup complete!" >&2
    }
    
    if [[ ! -d "$VENV_DIR" ]] || [[ ! -f "$VENV_DIR/bin/python" ]]; then
      setup_venv
    fi
    
    # Verify torch is importable (might need reinstall after system update)
    if ! "$VENV_DIR/bin/python" -c "import torch" 2>/dev/null; then
      echo "PyTorch import failed, reinstalling..." >&2
      setup_venv
    fi
    
    # Add CUDA and system libraries
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${cuda}/lib64:${stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    
    # Check if first arg is a .py file
    if [[ $# -gt 0 && "$1" == *.py ]]; then
      # Run the user's script directly
      exec "$VENV_DIR/bin/python" "$@"
    elif [[ $# -gt 0 && "$1" == "--text" ]] || [[ $# -gt 0 && "$1" == "-t" ]]; then
      # Quick generation mode
      exec "$VENV_DIR/bin/python" ${quickGenScriptFile} "$@"
    elif [[ $# -eq 0 ]]; then
      echo "Qwen3-TTS Runner (Blackwell SM120 via PyTorch nightly)"
      echo ""
      echo "Usage:"
      echo "  qwen3-tts script.py              # Run a custom TTS script"
      echo "  qwen3-tts --text 'Hello' [opts]  # Quick generation"
      echo ""
      echo "Quick generation options:"
      echo "  --text, -t TEXT        Text to synthesize (required)"
      echo "  --instruct, -i DESC    Voice description for VoiceDesign"
      echo "  --language, -l LANG    Language (default: English)"
      echo "  --output, -o FILE      Output file (default: output.wav)"
      echo "  --model, -m MODEL      Model name (default: VoiceDesign)"
      echo ""
      echo "Example:"
      echo "  qwen3-tts -t 'Hello world' -i 'cheerful young female voice'"
      echo ""
      echo "For custom scripts, use the qwen_tts Python package:"
      echo "  from qwen_tts import Qwen3TTSModel"
      echo "  model = Qwen3TTSModel.from_pretrained(...)"
      exit 0
    else
      # Pass through to python
      exec "$VENV_DIR/bin/python" "$@"
    fi
  '';

  meta = {
    description = "Run Qwen3-TTS for voice synthesis with VoiceDesign (Blackwell SM120)";
    mainProgram = "qwen3-tts";
  };
}
