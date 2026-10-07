/** Build WoW-compatible textures from the original ElementHousing artwork; requires sharp for development only. */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sources = path.join(root, 'Media', 'Source');

/** Encode an uncompressed 32-bit TGA with top-left origin and eight alpha bits. */
async function writeTexture(source, destination, size) {
    const rgba = await sharp(source).resize(size, size).ensureAlpha().raw().toBuffer();
    const header = Buffer.alloc(18);
    header[2] = 2;
    header.writeUInt16LE(size, 12);
    header.writeUInt16LE(size, 14);
    header[16] = 32;
    header[17] = 0x28;
    const bgra = Buffer.from(rgba);
    for (let i = 0; i < bgra.length; i += 4) {
        bgra[i] = rgba[i + 2];
        bgra[i + 2] = rgba[i];
    }
    await fs.writeFile(destination, Buffer.concat([header, bgra]));
}

await fs.mkdir(path.join(root, 'Media', 'Icons'), { recursive: true });
await writeTexture(path.join(sources, 'Icon.png'), path.join(root, 'Media', 'Icon.tga'), 256);
for (const name of (await fs.readdir(sources)).filter(name => name.endsWith('.svg')).sort()) {
    await writeTexture(path.join(sources, name), path.join(root, 'Media', 'Icons', name.replace('.svg', '.tga')), 64);
}
