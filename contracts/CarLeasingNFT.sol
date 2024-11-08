// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";

/**
 * @title CarLeasingNFT
 * @dev This contract implements an NFT representing cars available for leasing.
 * Each car has specific attributes and is represented by a unique token ID.
 */
 
contract CarLeasingNFT is ERC721, Ownable {
    // Counter for the next token ID to be minted
    uint256 public nextTokenId;

    // Struct to hold details about each car
    struct Car {
        string model;
        string colour;
        uint256 yearOfMatriculation;
        uint256 originalValue;
    }

    // Mapping from token ID to Car details
    mapping(uint256 => Car) public carDetails;

    // Counter for leasing deals
    uint256 public dealCounter;

    // Struct to hold details about a leasing deal
    struct Deal {
        address lessee;
        uint256 carId;
        uint256 totalLockedAmount;
        bool bilBoydConfirmed;
        bool lesseeConfirmed;
        uint256 nextPaymentDue;
    }

    // Mapping from deal ID to Deal details
    mapping(uint256 => Deal) public deals;

    /**
     * @dev Contract constructor that initializes the ERC721 token with a name and symbol.
     * Sets the initial token ID to 1.
     */
    constructor() ERC721("BilBoyd Car", "BBCAR") {
        nextTokenId = 1;
    }

    // Here starts task 1

    /**
     * @dev Function to mint a new car NFT.
     * Can only be called by the owner of the contract.
     * @param to The address that will receive the minted NFT.
     * @param model The model of the car.
     * @param colour The colour of the car.
     * @param yearOfMatriculation The year the car was registered.
     * @param originalValue The original value of the car.
     */
    function mintCar(
        address to,
        string memory model,
        string memory colour,
        uint256 yearOfMatriculation,
        uint256 originalValue
    ) public onlyOwner {
        uint256 tokenId = nextTokenId; // Assign the next token ID
        _safeMint(to, tokenId); // Mint the NFT safely to the recipient

        // Create a new Car struct and store it in the mapping
        carDetails[tokenId] = Car({
            model: model,
            colour: colour,
            yearOfMatriculation: yearOfMatriculation,
            originalValue: originalValue
        });

        nextTokenId++; // Increment the token ID counter for the next mint
    }

    /**
     * @dev Function to retrieve car details by token ID.
     * @param tokenId The ID of the token whose car details are being requested.
     * @return model The model of the car.
     * @return colour The colour of the car.
     * @return yearOfMatriculation The year the car was registered.
     * @return originalValue The original value of the car.
     */
    function getCarDetails(uint256 tokenId)
        public
        view
        returns (
            string memory model,
            string memory colour,
            uint256 yearOfMatriculation,
            uint256 originalValue
        )
    {
        // Check if the token exists
        require(_exists(tokenId), "Token does not exist");

        Car memory car = carDetails[tokenId]; // Retrieve car details
        return (
            car.model,
            car.colour,
            car.yearOfMatriculation,
            car.originalValue
        );
    }

    // Here starts task 2

    /**
     * @dev Function to calculate the monthly quota for a leasing deal.
     * @param originalValue The original value of the car.
     * @param mileage The current mileage of the car.
     * @param driverAge The age of the driver.
     * @param drivingExperienceYears The number of years the driver has been driving.
     * @return monthlyQuota The calculated monthly quota for the lease.
     */
    function calculateMonthlyQuota(
        uint256 originalValue,
        uint256 mileage,
        uint256 driverAge,
        uint256 drivingExperienceYears
    ) public pure returns (uint256) {
        uint256 adjustedValue = originalValue;

        // Mileage discount
        if (mileage > 200000) {
            adjustedValue = (originalValue * 25) / 100; // 75% reduction
        } else if (mileage > 100000) {
            adjustedValue = (originalValue * 50) / 100; // 50% reduction
        }

        // Driver discount
        if (driverAge > 25 && drivingExperienceYears >= 20) {
            adjustedValue = (adjustedValue * 70) / 100; // 30% discount
        } else if (driverAge > 25 && drivingExperienceYears >= 10) {
            adjustedValue = (adjustedValue * 80) / 100; // 20% discount
        } else if (driverAge > 25 && drivingExperienceYears >= 5) {
            adjustedValue = (adjustedValue * 90) / 100; // 10% discount
        }

        // Monthly rent is 5% of adjusted value
        uint256 monthlyQuota = (adjustedValue * 5) / 100;

        return monthlyQuota;
    }

    // Here starts task 3

    /**
     * @dev Function to register a leasing deal for a car.
     * @param carId The ID of the car being leased.
     */
    function registerDeal(uint256 carId) public payable {
        require(_exists(carId), "Car does not exist");
        require(msg.value > 0, "Must send payment");

        uint256 monthlyQuota = calculateMonthlyQuota(
            carDetails[carId].originalValue,
            0, // Assume mileage is set as zero for simplicity
            30, // Dummy age for testing
            10 // Dummy driving experience for testing
        );

        uint256 requiredAmount = monthlyQuota * 4; // 3-month down payment + 1st month
        require(msg.value == requiredAmount, "Incorrect payment amount");

        dealCounter++;
        deals[dealCounter] = Deal({
            lessee: msg.sender,
            carId: carId,
            totalLockedAmount: msg.value,
            bilBoydConfirmed: false,
            lesseeConfirmed: false,
            nextPaymentDue: block.timestamp + 30 days
        });
    }

    /**
     * @dev Function to confirm the leasing deal.
     * @param dealId The ID of the deal being confirmed.
     * @param byBilBoyd A boolean indicating if BilBoyd is confirming.
     */
    function confirmDeal(uint256 dealId, bool byBilBoyd) public {
        Deal storage d = deals[dealId];
        if (byBilBoyd) {
            d.bilBoydConfirmed = true;
        } else {
            d.lesseeConfirmed = true;
        }
        // All criteria met
        require(d.lesseeConfirmed && d.bilBoydConfirmed, "Both needs confirm");
        payable(d.lessee).transfer(d.totalLockedAmount);
    }

    // Here starts task 4

    /**
     * @dev Function for the lessee to make monthly payments.
     * @param dealId The ID of the deal for which the payment is being made.
     */
    function makeMonthlyPayment(uint256 dealId) public payable {
        Deal storage d = deals[dealId];
        require(d.lessee == msg.sender, "Only lessee can make payments");
        require(d.bilBoydConfirmed, "Deal must be confirmed by BilBoyd");
        require(block.timestamp >= d.nextPaymentDue, "Payment not due yet");

        uint256 monthlyQuota = calculateMonthlyQuota(
            carDetails[d.carId].originalValue,
            0, // Assume mileage is set as zero for simplicity
            30, // Dummy age for testing
            10 // Dummy driving experience for testing
        );

        require(msg.value == monthlyQuota, "Incorrect payment amount");
        d.nextPaymentDue = block.timestamp + 30 days; // Set next payment due date
    }

    /**
     * @dev Function to repossess the car if the lessee fails to make payments.
     * @param dealId The ID of the deal for which the payment is overdue.
     */
    function repossessCar(uint256 dealId) public onlyOwner {
        Deal storage d = deals[dealId];
        require(block.timestamp > d.nextPaymentDue + 7 days, "Grace period not over");
        require(d.bilBoydConfirmed, "Deal must be confirmed by BilBoyd");

        // Repossess the car by resetting the deal
        delete deals[dealId];
    }
}
