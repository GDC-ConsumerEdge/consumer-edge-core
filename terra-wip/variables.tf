/**
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
variable "enable" {
  description = "Actually enable the APIs listed"
  default     = true
}

variable "organization_id" {
  description = "The organization id for the associated services"
  default = "1011923829955" // replace with your org id  
}

variable "billing_account" {
  description = "The ID of the billing account to associate this project with"
  type = string
  default = "011142-1014EF-012029"
}
