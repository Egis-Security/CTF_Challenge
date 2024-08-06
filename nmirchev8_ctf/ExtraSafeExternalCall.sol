// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract ExtraSafeExternalCall{
  bytes4 internal constant NO_CONTRACT_SIG = 0x0c3b563c;
  bytes4 internal constant NO_GAS_FOR_CALL_EXACT_CHECK_SIG = 0xafa32a2c;
  bytes4 internal constant NOT_ENOUGH_GAS_FOR_CALL_SIG = 0x37c3be29;
 
  function _callWithExactGasSafeReturnData(
    bytes memory payload,
    address target,
    uint256 gasLimit
  ) internal returns (bool success, bytes memory retData, uint256 gasUsed) {
    // allocate retData memory ahead of time
    uint16 maxReturnDataBytes = 2 * 32;
    retData = new bytes(maxReturnDataBytes);
    uint16 gasForCallExactCheck = 5_000;
    assembly {
      // solidity calls check that a contract actually exists at the destination, so we do the same
      // Note we do this check prior to measuring gas so gasForCallExactCheck (our "cushion")
      // doesn't need to account for it.
      if iszero(extcodesize(target)) {
        mstore(0x0, NO_CONTRACT_SIG)
        revert(0x0, 0x4)
      }

      let g := gas()
      // Compute g -= gasForCallExactCheck and check for underflow
      // The gas actually passed to the callee is _min(gasAmount, 63//64*gas available).
      // We want to ensure that we revert if gasAmount >  63//64*gas available
      // as we do not want to provide them with less, however that check itself costs
      // gas. gasForCallExactCheck ensures we have at least enough gas to be able
      // to revert if gasAmount >  63//64*gas available.
      if lt(g, gasForCallExactCheck) {
        mstore(0x0, NO_GAS_FOR_CALL_EXACT_CHECK_SIG)
        revert(0x0, 0x4)
      }
      g := sub(g, gasForCallExactCheck)
      // if g - g//64 <= gasAmount, revert. We subtract g//64 because of EIP-150
      if iszero(gt(sub(g, div(g, 64)), gasLimit)) {
        mstore(0x0, NOT_ENOUGH_GAS_FOR_CALL_SIG)
        revert(0x0, 0x4)
      }

      // We save the gas before the call so we can calculate how much gas the call used
      let gasBeforeCall := gas()
      // call and return whether we succeeded. ignore return data
      // call(gas,addr,value,argsOffset,argsLength,retOffset,retLength)
      success := call(gasLimit, target, 0, add(payload, 0x20), mload(payload), 0x0, 0x0)
      gasUsed := sub(gasBeforeCall, gas())

      // Store the length of the copied bytes
      mstore(retData, maxReturnDataBytes)
      // copy the bytes from retData[0:maxReturnDataBytes]
      returndatacopy(add(retData, 0x20), 0x0, maxReturnDataBytes)
    }
    return (success, retData, gasUsed);
  }


  /// @dev A function to call untrusted target contract and to be safe from return gas bombs and gas griefing attacks
  function callContractSafe(bytes memory payload, address target, uint256 gasLimit) external returns (bool success, bytes memory returnData) { 
     (success, returnData, ) =_callWithExactGasSafeReturnData(payload, target, gasLimit);
  }
}