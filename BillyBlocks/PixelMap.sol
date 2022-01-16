//Library designed for BillyBlocks Contract
// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

library PixelMap {
    //Struct of what we will keep track of
    struct Pixel {
        uint256 id;
        address ownerAddress;
        string colorHex;
        string ipfsHttp;
    }

    // Stores all accessors
    struct Map {
        uint256[] keys;
        mapping(uint256 => Pixel) pixels;
        mapping(uint256 => bool) inserted;
        // mapping(uint256 => uint) indexOf;
    }

    function get(Map storage map, uint256 key) external view returns (Pixel memory) {
        return map.pixels[key];
    }

    function getKeyAtIndex(Map storage map, uint256 index) external view returns (uint256) {
        return map.keys[index];
    }

    function size(Map storage map) external view returns (uint) {
        return map.keys.length;
    }

    function set(
        Map storage map,
        uint256 key,
        Pixel memory val
    ) external {
        if (map.inserted[key]) {
            map.pixels[key] = val;
        } else {
            map.inserted[key] = true;
            map.pixels[key] = val;
            // map.indexOf[key] = map.keys.length;

            map.keys.push(key);
        }
    }
}
