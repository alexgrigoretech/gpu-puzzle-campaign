# Building the solver (KeyHunt-Cuda) natively for your GPU

This toolkit calls a compiled KeyHunt-Cuda binary; it does not ship one. Build it
from the upstream project. These are the notes that produced a clean build on
Windows with a recent CUDA toolkit and an Ada (RTX 40-series, sm_89) card.

## Toolchain
- CUDA Toolkit (13.x works): `winget install Nvidia.CUDA`.
- Visual Studio 2022 Build Tools with the **Desktop development with C++** workload,
  which must include **MSVC v143** and a **Windows 11 SDK**. Installing only the
  Build Tools shell is not enough; the compiler and SDK are the parts nvcc needs.
  `winget install Microsoft.VisualStudio.2022.BuildTools`, then in the VS Installer
  tick MSVC v143 and the Windows SDK (or add the VCTools workload with
  `--includeRecommended`). `nvidia-smi -pl`, silent VS installs, and scheduled-task
  creation all need an elevated shell.
- git.

## Get the source
Clone the upstream solver (this repo is separate from it):
`git clone https://github.com/Qalander/KeyHunt-Cuda`

## Retarget for your GPU and toolkit
In `KeyHunt-Cuda\KeyHunt-Cuda.vcxproj`:
- Set the CUDA CodeGeneration to your card's architecture, e.g. `compute_89,sm_89`
  for Ada (RTX 40-series). Look up your arch on NVIDIA's CUDA GPUs list.
- The stock project imports `CUDA 10.0.props` / `.targets`. Point those at your
  installed version, or import them by **absolute path** from the toolkit's
  `extras\visual_studio_integration\MSBuildExtensions\` folder. The absolute-path
  route avoids needing admin to copy them into Program Files.

## Build
From a shell with `CUDA_PATH` set to your toolkit, build the **solution** (not the
`.vcxproj` directly) so `$(SolutionDir)` resolves and the CPU files find the bundled
gmp:

```
msbuild KeyHunt-Cuda.sln /t:Rebuild /p:Configuration=Release /p:Platform=x64 ^
  /p:PlatformToolset=v143 /p:WindowsTargetPlatformVersion=10.0.26100.0
```

(Use whichever Windows SDK version you installed.)

## Known breakage on CUDA 13.x
`cudaDeviceProp::computeMode` was removed. If the build stops on it, delete the one
diagnostic `printf` in `GPU/GPUEngine.cu` that references
`sComputeMode[deviceProp.computeMode]`; it only prints the device's compute mode.

## Tuning
`--gpux` sets the grid. On an RTX 4070 Ti, `960,256` was about 23% faster than the
auto grid. Try a few values and watch the reported Mk/s, then put your best one in
`config.ps1` as `$Grid`.

## Point the toolkit at it
Set `$Exe` in `config.ps1` to the built `KeyHunt-Cuda.exe`. Verify it runs and sees
your card with `KeyHunt-Cuda.exe -l`, and that `KeyHunt-Cuda.exe -c -g` passes its
self-test for compressed P2PKH addresses.
