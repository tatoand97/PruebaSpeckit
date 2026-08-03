# Contact Requests Specification

## Purpose

Allow an unauthenticated visitor to register a contact request, receive a privacy-preserving confirmation, and get actionable field errors without persisting invalid data.

## Requirements

### Requirement: Register a contact request

The system MUST allow a visitor to register a contact request by providing a name, email address, and message without prior authentication.

#### Scenario: Visitor submits valid contact data

- **WHEN** a visitor submits a valid name, email address, and message
- **THEN** the system registers a new contact request

### Requirement: Validate the visitor name

The system MUST require a non-empty name of no more than 100 characters.

#### Scenario: Name at the maximum boundary

- **WHEN** the visitor submits a name containing exactly 100 characters
- **THEN** the name is accepted

#### Scenario: Missing or oversized name

- **WHEN** the visitor submits an empty name or a name longer than 100 characters
- **THEN** the request is rejected with an error associated with the name field

### Requirement: Validate the email address

The system MUST require an email address containing exactly one `@`, a non-empty local part, a domain containing at least one dot, and no spaces.

#### Scenario: Email satisfies the current rule

- **WHEN** the visitor submits an email with exactly one `@`, a non-empty local part, a dotted domain, and no spaces
- **THEN** the email field is accepted

#### Scenario: Email violates the current rule

- **WHEN** the visitor submits an email without a domain, without `@`, with multiple `@` characters, with an empty local part, or with spaces
- **THEN** the request is rejected with an error associated with the email field

### Requirement: Validate the contact message

The system MUST require a non-empty message between 10 and 1,000 characters inclusive.

#### Scenario: Message at either valid boundary

- **WHEN** the visitor submits a message containing exactly 10 or exactly 1,000 characters
- **THEN** the message is accepted

#### Scenario: Message outside the permitted range

- **WHEN** the visitor submits an empty message, fewer than 10 characters, or more than 1,000 characters
- **THEN** the request is rejected with an error associated with the message field

### Requirement: Reject invalid requests atomically

The system MUST reject a request when any input field is invalid, report every detected field error explicitly, and MUST NOT persist any part of the invalid request.

#### Scenario: Multiple fields are invalid

- **WHEN** a submission contains one or more invalid fields
- **THEN** the response identifies each invalid field and its reason and no contact request is stored

### Requirement: Assign registration metadata

The system MUST assign every valid contact request a unique identifier, the official system creation date and time, and the initial status `Pending`.

#### Scenario: Valid request is created

- **WHEN** a valid contact request is registered
- **THEN** it has a unique identifier, a creation timestamp, and status `Pending`

### Requirement: Return a privacy-preserving confirmation

The system MUST confirm a valid registration with only its unique identifier, creation date and time, and initial status `Pending`; it MUST NOT expose additional visitor contact data in that confirmation.

#### Scenario: Visitor receives the immediate result

- **WHEN** registration succeeds
- **THEN** the response contains the new identifier, creation timestamp, and `Pending` status and omits the name, email, message, and unrelated visitor data

### Requirement: Permit valid duplicates

The system MUST accept repeated valid submissions with the same email address and message as independent contact requests.

#### Scenario: Same valid contact is submitted more than once

- **WHEN** a visitor repeats a previously valid email address and message
- **THEN** each submission is registered separately with its own unique identifier and creation timestamp

### Requirement: Maintain current registration scope

The system MUST limit this capability to registering new contact requests. Sending email, authentication, automatic advisor assignment, CRM integration, and contact-request query, update, or deletion are excluded.

#### Scenario: Registration completes without downstream workflow

- **WHEN** a valid contact request is registered
- **THEN** the system returns its confirmation without requiring any excluded downstream capability

### Requirement: Meet the existing first-attempt outcome

The system MUST complete at least 19 of 20 consecutive valid registration attempts successfully on their first attempt under the existing validation sample conditions.

#### Scenario: Twenty consecutive valid attempts are sampled

- **WHEN** at least 20 consecutive valid registrations are evaluated
- **THEN** at least 19 complete successfully on the first attempt
