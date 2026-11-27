#!/usr/bin/env node
// Reduce Forever Nodes coordinates to coordinate-free per-zone node counts.

import fs from "node:fs";
import path from "node:path";

const options = {};
for (let i = 2; i < process.argv.length; i += 2) {
    const key = process.argv[i].replace(/^--/, "");
    options[key] = process.argv[i + 1];
}
for (const key of ["source", "output", "revision", "source-version", "generated"]) {
    if (!options[key]) throw new Error(`Missing --${key}`);
}

const text = fs.readFileSync(options.source, "utf8");
const lines = text.split(/\r?\n/);
const nodes = new Map();
const nodePattern = /^\s*\{ key = "([^"]+)", kind = "([^"]+)", name = "([^"]+)", icon = "[^"]+", skill = (\d+) \},\s*$/;
for (const line of lines) {
    const match = line.match(nodePattern);
    if (match) {
        nodes.set(match[1], { key: match[1], kind: match[2], name: match[3], skill: Number(match[4]) });
    }
}

const zones = new Map();
let inPoints = false;
let currentKey;
for (const line of lines) {
    if (line === "FN.points = {") {
        inPoints = true;
        continue;
    }
    if (!inPoints) continue;
    const block = line.match(/^    ([a-z0-9_]+) = \{$/);
    if (block) {
        currentKey = block[1];
        continue;
    }
    if (currentKey && line === "    },") {
        currentKey = undefined;
        continue;
    }
    const mapped = line.match(/^        \[(\d+)\]=\{(.*)\},?\s*$/);
    if (!currentKey || !mapped) continue;
    const mapID = Number(mapped[1]);
    const values = mapped[2].match(/-?\d+(?:\.\d+)?/g) ?? [];
    if (values.length % 2) throw new Error(`Odd coordinate count for ${currentKey} on map ${mapID}`);
    const unique = new Set();
    for (let i = 0; i < values.length; i += 2) unique.add(`${values[i]},${values[i + 1]}`);
    const meta = nodes.get(currentKey);
    if (!meta) throw new Error(`Point block ${currentKey} has no node definition`);
    if (!zones.has(mapID)) zones.set(mapID, new Map());
    const kinds = zones.get(mapID);
    if (!kinds.has(meta.kind)) kinds.set(meta.kind, []);
    kinds.get(meta.kind).push({ ...meta, count: unique.size });
}
if (!nodes.size || !zones.size) throw new Error("No node definitions or map points parsed");
for (const kinds of zones.values()) {
    for (const entries of kinds.values()) {
        entries.sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
    }
}

const q = JSON.stringify;
const output = [
    "-------------------------------------------------------------------------------",
    "-- Generated coordinate-free gathering summary. Do not edit by hand.",
    "-- Source: Forever Nodes Data.lua (MIT), based on GatherLite (MIT).",
    `-- Revision: ${options.revision}`,
    "-- Source coordinates are reduced to unique-position counts and are not shipped.",
    "-- See THIRD_PARTY_NOTICES.md for copyright and licence notices.",
    "-------------------------------------------------------------------------------",
    "local _, ns = ...",
    "",
    "ns.GatheringCatalog = {",
    "    source = {",
    `        name = ${q(`Forever Nodes ${options["source-version"]}`)},`,
    '        url = "https://github.com/LvcidLabs/ForeverNodes",',
    `        revision = ${q(options.revision)},`,
    `        generated = ${q(options.generated)},`,
    '        measure = "unique known positions",',
    "    },",
    "    zones = {",
];
for (const mapID of [...zones.keys()].sort((a, b) => a - b)) {
    output.push(`        [${mapID}] = {`);
    const kinds = zones.get(mapID);
    for (const kind of ["herb", "ore", "fish"]) {
        const entries = kinds.get(kind);
        if (!entries?.length) continue;
        output.push(`            ${kind} = {`);
        for (const entry of entries) {
            output.push(`                { key = ${q(entry.key)}, name = ${q(entry.name)}, skill = ${entry.skill}, count = ${entry.count} },`);
        }
        output.push("            },");
    }
    output.push("        },");
}
output.push("    },", "}", "");

fs.mkdirSync(path.dirname(options.output), { recursive: true });
fs.writeFileSync(options.output, output.join("\n"), "utf8");
console.log(`Wrote ${zones.size} map summaries to ${options.output}`);
if (options["report-map"]) {
    const mapID = Number(options["report-map"]);
    for (const [kind, entries] of zones.get(mapID) ?? []) {
        console.log(`map ${mapID} ${kind}: ${entries.map(entry => `${entry.name}=${entry.count}`).join(", ")}`);
    }
}
