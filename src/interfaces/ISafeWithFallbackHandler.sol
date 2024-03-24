// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {ISafe} from "./ISafe.sol";
import {ISafeFallbackHandler} from "./ISafeFallbackHandler.sol";

interface ISafeWithFallbackHandler is ISafe, ISafeFallbackHandler {}
