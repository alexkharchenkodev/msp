#ifndef TYPES_HPP
#define TYPES_HPP

#include <vector>
#include <cstdint>
#include "msp_id.hpp"

namespace msp {

/**
 * @brief ByteVector vector of bytes
 */
typedef std::vector<uint8_t> ByteVector;


/////////////////////////////////////////////////////////////////////
/// Generic message types

struct Message {
    virtual ID id() = 0;
};

// send to FC
struct Request : public Message {
    virtual void decode(const ByteVector &data) = 0;
};

// received from FC
struct Response : public Message {
    virtual ByteVector encode() const = 0;
};

} // namespace msp

#endif // TYPES_HPP
