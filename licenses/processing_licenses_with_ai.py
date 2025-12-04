import google.generativeai as genai
import warnings
import os

warnings.filterwarnings("ignore", category=FutureWarning)
genai.configure(api_key=os.environ.get("GOOGLE_API_KEY"))

file = genai.upload_file("temporal_print.yaml", mime_type="text/plain")
model = genai.GenerativeModel("gemini-2.5-pro")
# response = model.generate_content([file, "I want you to search ALL the 'not found' OR 'other' licenses on the temporal_print.yml, make a deep search on google or wherever to found this licenses and if they can be redistributed or not PLEASE. If there is another type of licenses which is not 'not found' OR 'other', PLEASE IGNORE IT. I need this to be 1000000000000000000 percent accurate, if you are NOT sure or didn't found something, DO NOT INVENT IT. Please, only search in official pages!!! Not a blog or something, I want the official pages of the program asked. By the way, PLEASE, GIVE ONLY THE INFORMATION, I DONT NEED MORE THINGS LIKE YOU TEXTING AND WRITING THINGS, JUST THE FORMAT ASKED, NOT EVEN IN PARENTHESES, I WANT THE SIMPLIEST NAME POSSIBLE, FOR EXAMPLE, IF ITS PROPIETARY LICENSE, DONT TELL ME THE WHOLE NAME, JUST PROPIETARY, AND THE SAME WITH OTHER EXAMPLES TOO, NOT JUST THIS ONE. IF YOU CANT FIND THE LICENSE LINK, PLEASE DONT PUT THE LICENSE TYPE, I NEED SO BAD THE RETRIEVED FROM INFORMATION, IF YOU DONT HAVE THAT, THE LICENSE TYPE MUST BE NOT FOUND. ALSO, THE NAMES MUST BE IN A SPECIFIC FORMAT, FIRST LETTER CAPITALS, THEN IN LOWERCASE LIKE THIS EXAMPLE: Apache-2.0, Propietary... IF ITS SOME TYPE OF ACRONYM, ALL CAPS PLEASE. JUST WRITE IT IN COMMON SENSE BASICALY, PLEASE, DONT IGNORE ANY 'other' OR 'not found' LICENSE, DO NOT IGNORE. IN THE LINK YOU RETRIEVED IT FROM, I NEED TO SEE THE DIRECT LINK, I DON'T NEED THE MAIN PAGE, JUST THE PAGE WHERE IT SAYS THE LICENSE. FINALLY, PLEASE PLEASE AND PLEASE, I NEED YOU TO BE CONSISTENT, SO YOU NEED TO BE 10000 PERCENT SURE, DONT TRY TO ACT COOL BY INVENTING SOME LICENSES, 10000000000 PERCENT ACCURACY, I WILL EXECUTE THIS CODE THOUSANDS OF TIMES, SO I NEED CONSISTENCY. PLEASE, DO NOT SEND ME 404 ERROR PAGES (not found), VERY IMPORTANT, IF YOU ARE NOT 100 PERCENT SURE ABOUT THE PAGE EXISTING, PLEASE, JUST SEND ME THE MAIN PAGE, PLEASE DO NOT TRY TO GUESS THE ROUTE TO THE LICENSE. IF THE LICENSE IS PROPIETARY, I JUST WANT TO KNOW ITS PROPIETARY, NOT A CUSTOM OR SOMETHING LIKE THAT, JUST PROPIETARY PLEASE. IF ANY CASE, IT GIVES OUT 2 LICENSES (or more), PLEASE, JUST WRITE ONE, THE MOST ACCURATE ONE, DONT ADD AND or SOMETHING LIKE THAT PLEASE, RESPECT THE yaml FORMAT, NO ANDs or ORs PLEASE. LAST THING, PLEASE DOUBLE CHECK (even TRIPLE if you can) BEFORE SENDING ME THIS. IN THIS FORMAT:\n <package_name>: \n  <version_id>: \n    License: <license_info> \n    Permission to redistribute: <true/false> \n    Retrieved from: <source_link>"])

prompt = """
I want you to search ALL the 'not found' OR 'other' licenses on the temporal_print.yml, 
make a deep search on google or wherever to found this licenses and if they can be redistributed or not PLEASE. 
If there is another type of licenses which is not 'not found' OR 'other', PLEASE IGNORE IT. 

I need this to be 1000000000000000000 percent accurate, if you are NOT sure or didn't found something, DO NOT INVENT IT. 
Please, only search in official pages!!! Not a blog or something, I want the official pages of the program asked. 

By the way, PLEASE, GIVE ONLY THE INFORMATION, I DONT NEED MORE THINGS LIKE YOU TEXTING AND WRITING THINGS, JUST THE FORMAT ASKED, 
NOT EVEN IN PARENTHESES, I WANT THE SIMPLIEST NAME POSSIBLE. 
FOR EXAMPLE, IF ITS PROPIETARY LICENSE, DONT TELL ME THE WHOLE NAME, JUST PROPIETARY, AND THE SAME WITH OTHER EXAMPLES TOO.

IF YOU CANT FIND THE LICENSE LINK, PLEASE DONT PUT THE LICENSE TYPE, I NEED SO BAD THE RETRIEVED FROM INFORMATION, 
IF YOU DONT HAVE THAT, THE LICENSE TYPE MUST BE NOT FOUND. 
ALSO, THE NAMES MUST BE IN A SPECIFIC FORMAT, FIRST LETTER CAPITALS, THEN IN LOWERCASE LIKE THIS EXAMPLE: Apache-2.0, Propietary... 
IF ITS SOME TYPE OF ACRONYM, ALL CAPS PLEASE. JUST WRITE IT IN COMMON SENSE BASICALY.

PLEASE, DONT IGNORE ANY 'other' OR 'not found' LICENSE, DO NOT IGNORE. 
IN THE LINK YOU RETRIEVED IT FROM, I NEED TO SEE THE DIRECT LINK, I DON'T NEED THE MAIN PAGE, JUST THE PAGE WHERE IT SAYS THE LICENSE. 

FINALLY, PLEASE, I NEED YOU TO BE CONSISTENT, SO YOU NEED TO BE 10000 PERCENT SURE, DONT TRY TO ACT COOL BY INVENTING SOME LICENSES.
PLEASE, DO NOT SEND ME 404 ERROR PAGES (not found), VERY IMPORTANT, IF YOU ARE NOT 100 PERCENT SURE ABOUT THE PAGE EXISTING, 
PLEASE, JUST SEND ME THE MAIN PAGE, PLEASE DO NOT TRY TO GUESS THE ROUTE TO THE LICENSE.

IF THE LICENSE IS PROPIETARY, I JUST WANT TO KNOW ITS PROPIETARY, NOT A CUSTOM OR SOMETHING LIKE THAT, JUST PROPIETARY PLEASE. 
IF ANY CASE, IT GIVES OUT 2 LICENSES (or more), PLEASE, JUST WRITE ONE, THE MOST ACCURATE ONE, DONT ADD AND or SOMETHING LIKE THAT PLEASE, 
RESPECT THE yaml FORMAT, NO ANDs or ORs PLEASE. LAST THING, PLEASE DOUBLE CHECK (even TRIPLE if you can) BEFORE SENDING ME THIS. 

IN THIS FORMAT:
 <package_name>: 
  <version_id>: 
    License: <license_info> 
    Permission to redistribute: <true/false> 
    Retrieved from: <source_link>
"""

response = model.generate_content([file, prompt])
print(response.text)
text = response.text.replace("```yaml", "").replace("```", "").strip()
with open("licenses_aux_llm.yaml", "w", encoding="utf-8") as f:
    f.write(text)

# This is to know which models are available with the API which is being used.
# print("--- AVAILABLE MODELS ---")
# for m in genai.list_models():
#     if 'generateContent' in m.supported_generation_methods:
#         print(m.name)