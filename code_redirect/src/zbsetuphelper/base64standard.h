#ifndef __BASE64STANDARD_H__
#define __BASE64STANDARD_H__
#include <string>
namespace base64standard
{
	std::string base64_encode(unsigned char const*, unsigned int len);  
	std::string base64_decode(std::string const& s); 
}

#endif // ___BASE64_H___