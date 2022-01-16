//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PixelMap.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract BillyBlock is ERC721URIStorage, Ownable {
    using PixelMap for PixelMap.Map;
    using PixelMap for PixelMap.Pixel;

    PixelMap.Map private map;   // global map keeping track of all important info - due to inner structs must be private
    uint256 public lastTokenId;  // global int keeping track of last Id
    uint8 public wave; // this is our global tracker for the wave we are on
    AggregatorV3Interface internal priceFeed; //this is chainlink live price feed

    constructor() ERC721("BillyBlock", "BILLY") {
        //the owner is set inside Ownable constructor
        lastTokenId = 1;
        wave = 1; // our first wave is 0 and can expand to desired
        priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
        //Mumbai network
        //Matic to USD = 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada // THIS DOESNT RETURN GREAT VALUES IDK IF WORKING
        //ETH to USD = 0x0715A7794a1dc8e42615F059dD6e406A6594651A //ETH TO USD WORKS
    }

    //These were for testing or possible logs to user may remove before true deploy
    event PixelMapId (
       uint256[] array
    );
    event PixelMapAddress (
       address[] array
    );
    event PixelMapColorHex (
       string[] array
    );
    event PixelMapIpfs (
       string[] array
    );

    function getLatestMaticPrice()
        public view returns (uint256)
    {
        (
            ,
            int price,
            ,
            ,

        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getMapSize()
        public view
        returns(uint256)
    {
        return map.size();
    }

    function getAllPixelId()
        public view
        returns (uint256[] memory)
    {
        return map.keys;
    }

    function getOnePixel(uint256 id)
        public view
        returns (uint256, address, string memory, string memory)
    {
        PixelMap.Pixel memory pixel = map.get(id);
        return (pixel.id, pixel.ownerAddress, pixel.colorHex, pixel.ipfsHttp);
    }

    function getAllPixels()
        public view
        returns (uint256[] memory, address[] memory, string[] memory, string[] memory)
    {
        uint256 curSize = map.size();

        uint256[] memory allIds = new uint256[](curSize);
        address[] memory allOwnerAddresses = new address[](curSize);
        string[] memory allHexStrings = new string[](curSize);
        string[] memory allIpfsStrings = new string[](curSize);

        for(uint256 i = 1; i < lastTokenId; i++) {
            PixelMap.Pixel memory pixel = map.get(i);
            allIds[i-1] = pixel.id;
            allOwnerAddresses[i-1] = pixel.ownerAddress;
            allHexStrings[i-1] = pixel.colorHex;
            allIpfsStrings[i-1] = pixel.ipfsHttp;
        }


        return (allIds, allOwnerAddresses, allHexStrings, allIpfsStrings);
    }

    function batchMintNFT(address recipient, string memory uri, string memory colorHex, uint256 amount)
        external onlyOwner checkIfPaused
    {

        for(uint256 i = 0; i < amount; i++) {
            //mint, set uri to token
            _mint(recipient, lastTokenId);
            _setTokenURI(lastTokenId, uri);

            //add to map
            PixelMap.Pixel memory defaultPixel;
            defaultPixel.id = lastTokenId;
            defaultPixel.ownerAddress = recipient;
            defaultPixel.colorHex = colorHex;
            defaultPixel.ipfsHttp = uri;

            map.set(lastTokenId, defaultPixel);

            //increment id
            lastTokenId++;

            //increase wave level based on lastTokenId
            if((lastTokenId/10000)+1 > wave) {
                wave++;
                // wave = uint8(currentWave);
            }
        }

        (uint256[] memory idArray, address[] memory addressArray, string[] memory colorHexArray, string[] memory ipfsArray) = getAllPixels();
        emit PixelMapId(idArray);
        emit PixelMapAddress(addressArray);
        emit PixelMapColorHex(colorHexArray);
        emit PixelMapIpfs(ipfsArray);
    }

    function getBillyPrice()
        public view returns(uint256)
    {
        if(wave == 1){
            return 0;
        } else {
            //must subtract 2 to properly offset prices how we want
            //we multiply by 10^8 because that is how ETH is reported
            return 2**(wave - 2) * (10 ** 8);
        }
    }

    function userBatchMintNFT(address recipient, string memory uri, string memory colorHex, uint256 amount)
    // function userBatchMintNFT()
        external checkIfPaused payable
    {
        //take the amount sent by user and Multiply by COIN-to-USD conversion to get USD then compare to USD price
        require(
            (msg.value * getLatestMaticPrice()) >= getBillyPrice(),
            "Not enough money given. Pay more to BILLY."
        );

        //transfer the value to owner
        payable(owner()).transfer(msg.value);

        //now do the same minting as for owner above
        for(uint256 i = 0; i < amount; i++) {
            //mint, set uri to token
            _mint(recipient, lastTokenId);
            _setTokenURI(lastTokenId, uri);

            //add to map
            PixelMap.Pixel memory defaultPixel;
            defaultPixel.id = lastTokenId;
            defaultPixel.ownerAddress = recipient;
            defaultPixel.colorHex = colorHex;
            defaultPixel.ipfsHttp = uri;

            map.set(lastTokenId, defaultPixel);

            //increment id
            lastTokenId++;

            //increase wave level based on lastTokenId
            if((lastTokenId/10000)+1 > wave) {
                wave++;
                // wave = uint8(currentWave);
            }
        }

        (uint256[] memory idArray, address[] memory addressArray, string[] memory colorHexArray, string[] memory ipfsArray) = getAllPixels();
        emit PixelMapId(idArray);
        emit PixelMapAddress(addressArray);
        emit PixelMapColorHex(colorHexArray);
        emit PixelMapIpfs(ipfsArray);
    }

    function batchEditMetadata(uint256[] memory listOfIds, string[] memory listOfHexStrings, string[] memory listOfNewIpfs)
        external
    {
        //this is our check that lists of equal length hae been given
        require(
            ((listOfIds.length == listOfHexStrings.length) && (listOfIds.length == listOfNewIpfs.length)),
            "BillyBlocks: mismatched length when editing color metadata. Must be 1-to-1."
        );

        for(uint256 i = 0; i < listOfIds.length; i++) {
            //get old pixel
            PixelMap.Pixel memory oldPixel = map.get(listOfIds[i]);

            //make sure this is the true owner of the id being edited
            require(
                (_msgSender() == oldPixel.ownerAddress),
                "BillyBlocks: you do not appear to be the owner of this Billy. Please use proper wallet."
            );

            //create new pixel
            PixelMap.Pixel memory newPixel;
            newPixel.id = listOfIds[i];
            newPixel.ownerAddress = oldPixel.ownerAddress;
            newPixel.colorHex = listOfHexStrings[i];
            newPixel.ipfsHttp = listOfNewIpfs[i];

            map.set(listOfIds[i], newPixel);

        }

        (uint256[] memory idArray, address[] memory addressArray, string[] memory colorHexArray, string[] memory ipfsArray) = getAllPixels();
        emit PixelMapId(idArray);
        emit PixelMapAddress(addressArray);
        emit PixelMapColorHex(colorHexArray);
        emit PixelMapIpfs(ipfsArray);
    }


    /*
        override the transfer and safetransfer functions
    */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        //solhint-disable-next-line max-line-length
        //be sure sender owns the token they are transfering
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        //set the new owner in the map
        //get old pixel
        PixelMap.Pixel memory oldPixel = map.get(tokenId);

        //create new pixel
        PixelMap.Pixel memory newPixel;
        newPixel.id = tokenId;
        newPixel.ownerAddress = to; //here is where we really are setting
        newPixel.colorHex = oldPixel.colorHex;
        newPixel.ipfsHttp = oldPixel.ipfsHttp;

        map.set(tokenId, newPixel);

        //perform actual transfer
        _transfer(from, to, tokenId);

        //emit update
        (uint256[] memory idArray, address[] memory addressArray, string[] memory colorHexArray, string[] memory ipfsArray) = getAllPixels();
        emit PixelMapId(idArray);
        emit PixelMapAddress(addressArray);
        emit PixelMapColorHex(colorHexArray);
        emit PixelMapIpfs(ipfsArray);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        //be sure sender owns the token they are transfering
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        //set the new owner in the map
        //get old pixel
        PixelMap.Pixel memory oldPixel = map.get(tokenId);

        //create new pixel
        PixelMap.Pixel memory newPixel;
        newPixel.id = tokenId;
        newPixel.ownerAddress = to; //here is where we adding new info
        newPixel.colorHex = oldPixel.colorHex;
        newPixel.ipfsHttp = oldPixel.ipfsHttp;
        map.set(tokenId, newPixel); //here is hwere the actual map gets set

        //perform actual safetransfer
        _safeTransfer(from, to, tokenId, _data);

        //emit update
        (uint256[] memory idArray, address[] memory addressArray, string[] memory colorHexArray, string[] memory ipfsArray) = getAllPixels();
        emit PixelMapId(idArray);
        emit PixelMapAddress(addressArray);
        emit PixelMapColorHex(colorHexArray);
        emit PixelMapIpfs(ipfsArray);
    }

    /*
        To be used with the above overriden safeTransferFrom
        Allows bulk transfer to help lower gas cost
    */
    function batchTransfer(
        address from,
        address to,
        uint256[] memory tokenIds
    ) external {
        for(uint256 i = 0; i < tokenIds.length; i++) {
            //dont require safety check b/c safeTransferFrom will do that
            safeTransferFrom(from, to, tokenIds[i], "");
        }

    }

    /* I originally thought this would help cut gas prices but...no */
    // function multiBatchTransfer(
    //     address from,
    //     address[] memory toArray,
    //     uint256[][] memory tokenIdsArray
    // ) external {
    //     require(toArray.length == tokenIdsArray.length, "Must have an equal number of addresses to token lists");

    //     for(uint256 i = 0; i < toArray.length; i++) {
    //         this.batchTransfer(from, toArray[i], tokenIdsArray[i]);
    //     }
    // }

    /*
        Create fallback function and event to notice
        I think this is overkill and solidity says only need for proxy or update design
        But implementing anyway
    */
    event FallbackEvent(address indexed _from, uint _value, string note);
    fallback() external payable
    {
        emit FallbackEvent(_msgSender(), msg.value, "Fallback function triggered");
    }
    receive() external payable {
        emit FallbackEvent(_msgSender(), msg.value, "Fallback function triggered");
    }

    /*
        The following is in case anyone finds a way to mess with contract it gives us time to fix
        This security measure is being followed as recommended by https://medium.com/coinmonks/common-attacks-in-solidity-and-how-to-defend-against-them-9bc3994c7c18
        The only function that uses this modifier is batchMint which can only be called by the owner in the first place
    */
    bool public contractPaused = false;
    event CircuitBreakerEvent(string note);
    function circuitBreaker()
        public onlyOwner
    {
        if (contractPaused == false) {
            contractPaused = true;
            emit CircuitBreakerEvent("Circuit breaker has been paused");
        }
        else {
            contractPaused = false;
            emit CircuitBreakerEvent("Circuit breaker has been resumed");
        }
    }
    // If the contract is paused, stop the modified function
    // Attach this modifier to all public functions
    modifier checkIfPaused() {
        require(contractPaused == false);
        _;
    }
}
