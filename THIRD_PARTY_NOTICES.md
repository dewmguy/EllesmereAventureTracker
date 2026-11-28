# Third-Party Notices

## Forever Nodes and GatherLite

`Data/GatheringCatalog.lua` is a coordinate-free aggregate generated from
Forever Nodes `Data.lua` at revision
`60d61b4f477a23d02d9707399fe8f1a7d2525d10`. It retains node names, required
skills and counts of unique known positions by map. It contains no source
coordinates.

Forever Nodes is copyright © 2026 Lvcid and distributed under the MIT License:

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

Forever Nodes states that its node data is converted from GatherLite 8.4.6 by
Wuild. GatherLite is copyright © 2019 Wuild and distributed under the same MIT
License text above. The Forever Nodes credits describe that database as a
Wowhead import; Adventure Tracker therefore ships only its derived zone counts,
not the coordinates or a mapping interface.

Sources:

- <https://github.com/LvcidLabs/ForeverNodes>
- <https://github.com/LvcidLabs/ForeverNodes/blob/main/LICENSE>
- <https://github.com/LvcidLabs/ForeverNodes/blob/main/CREDITS.txt>

## OneCast

`Data/CookingFoods.lua` contains recipe-spell and product-item identifiers
cross-checked against OneCast `Cooking.lua`. `Data/FishingLevels.lua` adapts
the effective-skill thresholds and zone identifiers in OneCast
`ZoneLevels.lua` and `ZoneNames.lua` at revision
`2f4a6b02e25ef5f4ab025a14b09f48c352948c3a`. The source separates documented
Forever player measurements from Classic baselines originating in the CMaNGOS
Classic 1.12 world database and cross-checks those baselines against
AzerothCore. OneCast is by rynmon and is declared MIT licensed on CurseForge.

The associated MIT permission notice is:

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

Sources:

- <https://github.com/rynmon/OneCast>
- <https://www.curseforge.com/wow/addons/onecast/license>

## Dwarf Explorer's Bible recipe catalogue

`Data/RecipeCatalog.lua` is adapted from the generated `Data.lua` in Dwarf
Explorer's Bible at blob
`a6d5d40fd4b5cf61a7d2d857acbf34c7e06989d1`. The snapshot contains recipe
products, spell IDs, professions, skill thresholds and reagents generated from
WoW Forever 1.60.1.71037 client tables plus the upstream project's documented
70959 hotfix overlay. Adventure Tracker does not copy its UI, price cache, loot
history or player observations.

Dwarf Explorer's Bible is copyright © 2026 Kenny (masterred92) and distributed
under the MIT License:

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

Source:

- <https://github.com/masterred92/DwarfExplorersBible>

World of Warcraft game data and names are © Blizzard Entertainment, Inc.

## What's Training?

The static WoW: Forever class-trainer catalog in `Data/ClassTraining/` and the
profession learn-at/source/base-price facts in `Data/ProfessionTraining.lua`
are adapted from [What's Training?](https://github.com/fusionpit/WhatsTraining),
commit `59763c2105428ccf99926919824c23d850bfbaa4`. Adventure Tracker does not copy
the upstream UI, route planner, saved variables or player observations.

MIT License

Copyright (c) 2019

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## QuestieDB

QuestieDB is an optional runtime data provider. Adventure Tracker does not
redistribute its database; users install and update it separately.

Adventure Tracker also mirrors the 18 factual quest-ID exclusions added by
Questie commit `01979e26f60047cd6fda53d4680fc6233c9074ae` for Duskwood's
Season of Discovery missions on non-SoD clients. Questie is distributed under
the GNU General Public License v3.0. No Questie UI, routing code or database is
copied.

Sources:

- <https://github.com/Questie/Questie/commit/01979e26f60047cd6fda53d4680fc6233c9074ae>
- <https://github.com/Questie/Questie/blob/master/LICENSE>

## All The Things

Adventure Tracker uses All The Things' public availability research to exclude
the factual quest ID 93928, Of Mice and Milk, which its Forever database marks
as beta-only content removed before launch. No All The Things code or database
is redistributed. All The Things is available under the MIT License.

Sources:

- <https://github.com/ATTWoWAddon/AllTheThings/commit/efb59f27785585017cd84d7ddf99dbe8a3aa3622>
- <https://github.com/ATTWoWAddon/AllTheThings/blob/master/LICENSE>
