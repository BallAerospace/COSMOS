/*
# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
*/

// This is typically used with the CosmosAuth.updateToken method.
// Passing a value of 30 to this method means that the access token
// will be updated if it is currently expired or if it will expire
// within the next 30 seconds.
Object.defineProperty(CosmosAuth, 'defaultMinValidity', {
  value: 30,
  writable: false,
  enumerable: true,
  configurable: false,
})
