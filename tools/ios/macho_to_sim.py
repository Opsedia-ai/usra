# Re-tags an arm64 iOS object file (MH_OBJECT) as iOS Simulator, in place.
# Used by mlkit_simulator.sh.
#
# Objects with LC_BUILD_VERSION just get platform 7. Older ones carry
# LC_VERSION_MIN_IPHONEOS (16 bytes), which has no simulator form, so it is
# replaced by LC_BUILD_VERSION (24 bytes); when there is no room after the
# load commands, everything after them moves down 8 bytes and every file
# offset is adjusted. (`xcrun vtool` refuses: "not enough space".)
#
#   python3 -I macho_to_sim.py FILE.o
import struct
import sys

LC_SEGMENT_64, LC_SYMTAB, LC_DYSYMTAB = 0x19, 0x2, 0xB
LC_VERSION_MIN_IPHONEOS, LC_BUILD_VERSION = 0x25, 0x32
# linkedit_data_command: dataoff at +8.
LINKEDIT_DATA = {0x1D, 0x1E, 0x26, 0x29, 0x2B, 0x2E, 0x80000033, 0x80000034}
PLATFORM_IOSSIMULATOR = 7
ZEROFILL = {0x1, 0xC, 0x12}  # S_ZEROFILL, S_GB_ZEROFILL, S_THREAD_LOCAL_ZEROFILL

path = sys.argv[1]
b = bytearray(open(path, 'rb').read())
magic, _, _, filetype, ncmds, sizeofcmds = struct.unpack_from('<6I', b, 0)
assert magic == 0xFEEDFACF and filetype == 1, 'not a 64-bit object file'


def commands():
    off = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<2I', b, off)
        yield off, cmd, size
        off += size


def sections(seg):
    nsects = struct.unpack_from('<I', b, seg + 64)[0]
    return range(seg + 72, seg + 72 + 80 * nsects, 80)


for off, cmd, _ in commands():
    if cmd == LC_BUILD_VERSION:
        struct.pack_into('<I', b, off + 8, PLATFORM_IOSSIMULATOR)
        open(path, 'wb').write(b)
        sys.exit(0)

found = [off for off, cmd, _ in commands() if cmd == LC_VERSION_MIN_IPHONEOS]
if not found:
    sys.exit(0)
vmin = found[0]
version, sdk = struct.unpack_from('<2I', b, vmin + 8)
end = 32 + sizeofcmds
offsets = [struct.unpack_from('<I', b, s + 48)[0]
           for off, cmd, _ in commands() if cmd == LC_SEGMENT_64 for s in sections(off)]
data_start = min([o for o in offsets if o] or [len(b)])
delta = 0 if data_start - end >= 8 else 8


def shift(off, fmt='<I'):
    v = struct.unpack_from(fmt, b, off)[0]
    if v:
        struct.pack_into(fmt, b, off, v + delta)


if delta:
    for off, cmd, _ in commands():
        if cmd == LC_SEGMENT_64:
            shift(off + 40, '<Q')  # fileoff
            for s in sections(off):
                if struct.unpack_from('<I', b, s + 64)[0] & 0xFF not in ZEROFILL:
                    shift(s + 48)  # offset
                shift(s + 56)  # reloff
        elif cmd == LC_SYMTAB:
            shift(off + 8)  # symoff
            shift(off + 16)  # stroff
        elif cmd == LC_DYSYMTAB:
            for k in (6, 8, 10, 12, 14, 16):  # tocoff ... locreloff
                shift(off + 8 + 4 * k)
        elif cmd in LINKEDIT_DATA:
            shift(off + 8)

build = struct.pack('<6I', LC_BUILD_VERSION, 24, PLATFORM_IOSSIMULATOR, version, sdk, 0)
load_commands = bytes(b[32:vmin]) + build + bytes(b[vmin + 16:end])
rest = bytes(b[end:]) if delta else bytes(b[end + 8:])  # else: eat 8 bytes of padding
struct.pack_into('<I', b, 20, sizeofcmds + 8)
open(path, 'wb').write(bytes(b[:32]) + load_commands + rest)
