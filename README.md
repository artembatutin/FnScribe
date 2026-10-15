# FnScribe

FnScribe is an AI-powered macOS dictation app that turns speech into polished, context-aware text for writing, productivity, and coding workflows.

## 🎯 Key Features

### **Real-time Streaming Transcription**
- **Live Voice Processing**: Convert speech to text in real-time with low latency
- **Intelligent Punctuation**: Automatic capitalization and punctuation insertion
- **Noise Filtering**: Advanced audio processing to reduce background noise
- **Multi-language Support**: Support for various languages and accents

### **IDE Integration & File Tagging**
- **Smart File References**: Say "at app delegate swift" and get `@AppDelegate.swift`
- **Workspace Discovery**: Automatically scans your IDE workspace for available files
- **Fuzzy Matching**: Intelligent matching of spoken file names to actual files
- **Multi-IDE Support**: Works with Cursor, Windsurf, VS Code, Xcode, and JetBrains IDEs

### **Personal Dictionary & Customization**
- **Custom Vocabulary**: Add technical terms, acronyms, and project-specific words
- **Vocabulary Suggestions**: Review unfamiliar words detected in dictation and save their preferred spelling
- **Optional Sentence Refinement**: Toggle local grammar correction and available Apple Intelligence rewriting in Settings → Dictionary
- **Syntax Transformation**: Convert spoken programming syntax to proper code format
- **Context-Aware Suggestions**: AI-powered suggestions based on your coding context

### **Advanced Dictation Features**
- **Syntax-Aware Dictation**: Speak code naturally and get properly formatted syntax
- **Snippet Library**: Store and insert frequently used code snippets via voice
- **Usage Dashboard**: Track your dictation patterns and productivity metrics

## 🚀 Quick Start

### Prerequisites
- macOS 14.0 or later
- Xcode 26 or later (for development)
- Microphone access permissions

### Installation

#### From Source
1. Clone the repository:
   ```bash
   git clone https://github.com/artembatutin/FnScribe.git
   cd FnScribe
   ```

2. Open the project in Xcode:
   ```bash
   open FnScribe.xcodeproj
   ```

3. Build and run the project (⌘+R)

#### From Release
Download the latest signed DMG file from the [Releases](https://github.com/artembatutin/FnScribe/releases) section.

## Local speech models

Open **Settings → Models** and choose **Download & use** for a model. The initial
model download needs an internet connection; recognition then runs locally.
The first Parakeet load can take a few minutes while macOS prepares the model for
the Neural Engine.

On Apple Silicon, FnScribe supports:

| Model | Approximate download | Languages |
| --- | --- | --- |
| Parakeet Ultra (recommended) | 630 MB | 25, automatically detected |
| Parakeet TDT 0.6B V3 | 485 MB | 25, automatically detected |

Ultra is a post-trained v3 variant; FluidAudio reports higher accuracy at similar
speed in its [published benchmarks](https://github.com/FluidInference/FluidAudio/blob/v0.17.7/Documentation/ASR/ParakeetUltra.md).
The [NVIDIA v3 model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
lists the supported languages. Both models support FnScribe's live preview and
final dictation. Live preview uses repeated audio windows; these are not the
separate English-only Parakeet EOU streaming models.

Existing Whisper models and saved selections continue to work. Whisper remains
available on Intel Macs and for languages outside Parakeet's coverage. Parakeet
variants are stored separately under `~/Library/Application Support/FnScribe/Models/parakeet`.

Parakeet V3 is by NVIDIA; Ultra is by Moondream, with Core ML conversions by
FluidInference. The downloaded models use the [CC BY 4.0 license](https://creativecommons.org/licenses/by/4.0/).

The integration pins [FluidAudio 0.17.7](https://github.com/FluidInference/FluidAudio/releases/tag/v0.17.7).
The regular unit suite uses offline fixtures. To run the optional hardware integration
check, set `FNSCRIBE_TEST_AUDIO` to a local speech audio file and
`FNSCRIBE_TEST_MODEL_CACHE` to a writable model cache directory in the test runner's
environment, then run `ParakeetSupportTests/testParakeetModelsEndToEnd`.
It downloads missing models and verifies final transcription and live preview
with network access disabled in the model runtime.

## 📖 Documentation

FnScribe includes comprehensive documentation for all its features:

- **[IDE File Tagging](docs/ide-file-tagging.md)** - Learn how to reference files in your IDE using voice commands
- **[Personal Dictionary](docs/personal-dictionary.md)** - Customize vocabulary and transformations
- **[Real-time Streaming Transcription](docs/real-time-streaming-transcription.md)** - Understand the transcription pipeline
- **[Syntax-Aware Dictation](docs/syntax-aware-dictation.md)** - Speak code naturally with proper formatting
- **[Snippets Library](docs/snippets-library.md)** - Manage and use code snippets via voice
- **[Usage Dashboard](docs/usage-dashboard.md)** - Track productivity and usage patterns

## 🏗️ Architecture

FnScribe is built with a clean, modular architecture:

```
FnScribe/
├── Application/          # App lifecycle and dependency management
├── Domain/              # Business logic and models
├── Infrastructure/      # External integrations and services
├── Presentation/        # UI components and views
└── FnScribeApp.swift # Main app entry point
```

### Core Components

- **AudioEngine**: Handles real-time audio capture and processing
- **SpeechRecognizer**: Manages speech-to-text conversion
- **TextInjectionService**: Injects transcribed text into active applications
- **WorkspaceScanner**: Discovers and monitors IDE workspaces
- **FileTagger**: Converts spoken file references to proper tags
- **SettingsStore**: Manages user preferences and configuration

## 🔧 Configuration

FnScribe offers extensive customization through its settings interface:

- **Audio Settings**: Microphone selection, noise reduction, sensitivity
- **Transcription Settings**: Language, punctuation, formatting options
- **IDE Integration**: Workspace scanning, file matching preferences
- **Personal Dictionary**: Custom words, transformations, snippets
- **Advanced Options**: Performance tuning, debug logging

## 🛠️ Development

### Building from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/artembatutin/FnScribe.git
   cd FnScribe
   ```

2. **Install dependencies**
   ```bash
   # Swift Package Manager dependencies are automatically resolved
   ```

3. **Open in Xcode**
   ```bash
   open FnScribe.xcodeproj
   ```

4. **Build and run in Xcode**
   - Select a target device/simulator
   - Press ⌘+R to build and run

5. **Or build from Terminal**
   ```bash
   make build
   make install
   ```

6. **Clean local build output**
   ```bash
   make clean
   ```

### Running Tests

```bash
# Run unit tests
xcodebuild test -project FnScribe.xcodeproj -scheme FnScribeTests -destination 'platform=macOS'
```

### Contributing

We welcome issues and pull requests through GitHub.

## 🐛 Troubleshooting

### Common Issues

**Microphone Permission Denied**
- Go to System Preferences → Security & Privacy → Privacy → Microphone
- Enable FnScribe in the microphone access list

**IDE Integration Not Working**
- Ensure your IDE is supported (Cursor, Windsurf, VS Code, Xcode, JetBrains)
- Check that accessibility permissions are enabled for FnScribe
- Verify workspace scanning is enabled in settings

**Speech Recognition Accuracy**
- Check microphone quality and positioning
- Adjust noise reduction settings
- Add custom vocabulary to personal dictionary

**Performance Issues**
- Reduce audio quality settings if needed
- Disable unnecessary features in settings
- Check system resource usage

### Getting Help

- **Documentation**: Check the `docs/` folder for detailed feature documentation
- **Issues**: Report bugs and request features on the [GitHub Issues](https://github.com/artembatutin/FnScribe/issues) page
- **Discussions**: Join community discussions in the [GitHub Discussions](https://github.com/artembatutin/FnScribe/discussions) section

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Apple Speech Framework for speech recognition capabilities
- SwiftUI community for UI components and inspiration
- Open source contributors who make projects like this possible

## 📊 Roadmap

- **Enhanced AI Integration**: Improved context-aware suggestions
- **Multi-language Support**: Expanded language recognition
- **Team Collaboration**: Shared dictionaries and configurations
- **Plugin Architecture**: Extensible plugin system for custom integrations
- **Cross-platform Support**: Windows and Linux versions

---

**Made for people who prefer speaking their thoughts into shape.**

For questions, support, or to contribute, please visit the [GitHub repository](https://github.com/artembatutin/FnScribe).
