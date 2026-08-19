# Copy this file to config.ps1 and edit for your machine.
# config.ps1 is gitignored so your local paths never get committed.

# Path to the compiled solver (KeyHunt-Cuda). See BUILD.md to build it for your GPU.
$Exe = 'C:\path\to\KeyHunt-Cuda\x64\Release\KeyHunt-Cuda.exe'

# Target address to search (default: Bitcoin puzzle 71, a public challenge address).
$Address = '1PWo3JeB9jrGwfHDNpdGK54CRas7fsVzXU'

# Keyspace to sweep, as hex. Default is the upper half of puzzle 71's range
# ([2^70, 2^71-1]); starting high keeps you off the crowded bottom where most
# hunters begin. Set RangeStartHex to '400000000000000000' to cover from the bottom.
$RangeStartHex = '600000000000000000'
$RangeEndHex   = '7fffffffffffffffff'

# Chunk size = 2^ChunkPow keys per solver invocation (40 => ~1.1e12 keys, a few
# minutes per chunk on a mid-range card). Smaller = finer ledger granularity.
$ChunkPow = 40

# GPU grid, passed to the solver's --gpux. Tune for your card; 960,256 was ~23%
# faster than auto on an RTX 4070 Ti.
$Grid = '960,256'
