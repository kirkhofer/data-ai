<#
https://learn.microsoft.com/en-us/azure/cognitive-services/openai/reference#completions
#>
$ErrorActionPreference="Stop"

$cfg=@{}
if( $PSScriptRoot -eq "")
{
  $file = Get-Content "aoai/.env"
}
else
{
  $file = Get-Content (Join-Path $PSScriptRoot ".env")
}
$file|%{$x,$y=$_.split("=");$cfg[$x]=$y}

$resource=$cfg["AOAI_NAME"]
$apiKey=$cfg["AOAI_KEY"]
$searchServiceName=$cfg["AZURE_SEARCH_SERVICE"]
$searchIndex=$cfg["AZURE_SEARCH_INDEX"]

$bingKey=$cfg["BING_KEY"]
$bingUrl=$cfg["BING_ENDPOINT"]

$searchKey=""
$searchToken=""
$searchKey=$cfg["AZURE_SEARCH_KEY"]

function Invoke-OpenAIPrompt
{
    param(
        [string]$ModelName="text-davinci-003",
        [Parameter(Mandatory=$true)]
        [string]$prompt,
        [int]$max_tokens=100,
        [float]$temperature=0.5,
        [float]$top_p=1,
        [float]$frequency_penalty=0,
        [float]$presence_penalty=0,
        [int]$best_of=1,
        [string[]]$stop,
        [switch]$AsJson
    )


    $body=@{}
    $body.Add("prompt",$prompt)
    $body.Add("max_tokens",$max_tokens)
    $body.Add("temperature",$temperature)
    $body.Add("top_p",$top_p)
    $body.Add("frequency_penalty",$frequency_penalty)
    $body.Add("presence_penalty",$presence_penalty)

    if( "gpt-35-turbo" -ne $ModelName )
    {
        $body.Add("best_of",$best_of)
    }

    $body.Add("stop",$stop)
    $body = $body | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($body)

    Write-Host "Len is $($body.length)"

    $uri = "https://{0}.openai.azure.com/openai/deployments/{1}/completions?api-version=2022-12-01" -f $resource,$ModelName
    $headers = @{
        "Content-Type" = "application/json"
        "api-key" = "$apiKey"
    }
    Write-Host $uri -ForegroundColor Green
    #Write-Host $body -ForegroundColor Yellow
    $resp = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method POST
    Write-Host "total_tokens=$($resp.usage.total_tokens)" -ForegroundColor Green

    if( $AsJson )
    {
        return $resp
    }
    else
    {
        return $resp.choices[0].text.replace("\n","`n").trim()
    }
}

function Invoke-OpenAIChatGPT
{
    param(
        [Parameter(Mandatory=$true)]
        $Messages,
        [string]$ModelName="gpt-35-turbo",
        [int]$max_tokens=1024,
        [float]$temperature=0.5,
        [float]$top_p=1,
        [float]$frequency_penalty=0,
        [float]$presence_penalty=0,
        [int]$keep=10,
        [switch]$AsJson
    )
    $body=@{}
    $body.Add("messages",$Messages)
    $body.Add("max_tokens",$max_tokens)
    $body.Add("temperature",$temperature)
    $body.Add("top_p",$top_p)
    $body.Add("frequency_penalty",$frequency_penalty)
    $body.Add("presence_penalty",$presence_penalty)
    $body.Add("stop",$stop)
    $body = $body | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($body)

    $uri = "https://{0}.openai.azure.com/openai/deployments/{1}/chat/completions?api-version=2023-03-15-preview" -f $resource,$ModelName
    $headers = @{
        "Content-Type" = "application/json"
        "api-key" = "$apiKey"
    }
    Write-Host $uri -ForegroundColor Green
    # Write-Host $body -ForegroundColor Yellow
    $resp = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method POST
    Write-Host "total_tokens=$($resp.usage.total_tokens)" -ForegroundColor Green

    if( $AsJson )
    {
        return $resp
    }
    else
    {
        return $resp.choices[0].message.content.replace("\n","`n").trim()
    }    
}

#https://learn.microsoft.com/en-us/azure/search/query-simple-syntax
function Invoke-SearchRequest
{
    param($method="GET", $requestUri, $body)
    # Adding 'odata.metadata=none' to the Accept header to make the response payloads more concise and readable.
    $headers=@{}
    # $header = @{"api-key"=$apiKey; "Accept"="application/json; odata.metadata=none"}

    $headers.Add("Accept","application/json; odata.metadata=none")
    if( "" -ne $searchKey )
    {
        $headers.Add("api-key",$searchKey)
    }
    else
    {
        $headers.Add("Authorization","Bearer $searchToken")
    }

    Write-Host $headers

    $resp = @{}
    $contentType = "application/json"
    Write-Host $requestUri -ForegroundColor Green
    if( $body )
    {
        # Adding 'charset=utf-8' to the Content-Type header so that we can index non-ASCII characters like accents from PowerShell.
        $contentType = "application/json; charset=utf-8"
        #$body = $body | ConvertTo-Json
        #$body = [System.Text.Encoding]::UTF8.GetBytes($body)
        Write-Host $body
        $resp = Invoke-RestMethod -Uri $requestUri -Method $method -Headers $headers -Body $body -ContentType $contentType 
    }
    else
    {
        $resp = Invoke-RestMethod -Uri $requestUri -Method $method -Headers $headers
    }
    # Write-Host "`$statusCode=$($resp.StatusCode)"
    return $resp
}

function Invoke-SearchBing
{
    param($params)

    $headers=@{"Ocp-Apim-Subscription-Key"=$bingKey}
    $baseUri = "$bingUrl/v7.0/search"

    $uri = $baseUri + "?" + $params

    $json = Invoke-RestMethod -Uri $uri -Headers $headers

    
    $src = [System.Text.StringBuilder]::new()
    # [void]$src.Append("Assistant helps the company employees with their healthcare plan questions and employee handbook questions.")
    [void]$src.Append("Answer ONLY with the facts listed in the list of sources below.")
    [void]$src.Append("If there isn't enough information below, say you don't know.")
    [void]$src.Append("Do not generate answers that don't use the sources below.")
    [void]$src.Append("If asking a clarifying question to the user would help, ask the question.")
    [void]$src.Append("Each source has a URL followed by colon and the actual information, always include the source URL for each fact you use in the response.")
    [void]$src.Append("Use square brakets to reference the source, e.g. [https://www.bing.com/page1].")
    [void]$src.AppendLine("Don't combine sources, list each source separately, e.g. [https://www.bing.com/page1][https://www.bing.com/page2].")

    [void]$src.Append("`n`n")
    [void]$src.AppendLine("Sources:")
    foreach($val in $json.webPages.value)
    {
        [void]$src.Append($val.url)
        [void]$src.AppendLine(":  ")
        [void]$src.AppendLine($val.snippet.Replace("`n","").Trim())
    }
    $messages=@()
    $messages+=@{role="system";content=$src.ToString()}
    $messages+=@{role="user";content=$question}
    return Invoke-OpenAIChatGPT -Messages $messages
}

return

$prompt="Write a tagline for an ice cream shop."
Invoke-OpenAIPrompt -prompt $prompt

$prompt="What day is today?"
Invoke-OpenAIPrompt -prompt $prompt
Invoke-OpenAIPrompt -ModelName "text-currie-001" -prompt $prompt -max_tokens 10

#Classification
$prompt="Classify the following news article into 1 of the following categories: 
categories: [Business, Tech, Politics, Sport, Entertainment]


news article: Donna Steffensen Is Cooking Up a New Kind of Perfection. The Internet's most beloved cooking guru has a buzzy new book and a fresh new perspective:


Classified category:"
Invoke-OpenAIPrompt -prompt $prompt

$prompt="Classify the following news article into 1 of the following categories: 
categories: [Business, Tech, Politics, Sport, Entertainment]


news article: Tiger Woods hit a poor drive today:


Classified category:"
Invoke-OpenAIPrompt -prompt $prompt

#Text to SQL
$prompt=@"
### Postgres SQL tables, with their properties:
#
# Employee(id, name, department_id)
# Department(id, name, address)
# Salary_Payments(id, employee_id, amount, date)
#
### A query to list the names of the departments which employed more than 10 employees in the last 3 months
"@
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 150 -temperature 0 -stop @("#",";")

$prompt="English:What time is it?`nSpanish:"
Invoke-OpenAIPrompt -prompt $prompt -stop @("`n")

$prompt="English:What time is it?`nFrench:"
Invoke-OpenAIPrompt -prompt $prompt -stop @("`n")

$prompt="Once upon a time"
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 5

#https://platform.openai.com/examples/default-tldr-summary
$prompt=@"
A neutron star is the collapsed core of a massive supergiant star, which had a total mass of between 10 and 25 solar masses, possibly more if the star was especially metal-rich.[1] Neutron stars are the smallest and densest stellar objects, excluding black holes and hypothetical white holes, quark stars, and strange stars.[2] Neutron stars have a radius on the order of 10 kilometres (6.2 mi) and a mass of about 1.4 solar masses.[3] They result from the supernova explosion of a massive star, combined with gravitational collapse, that compresses the core past white dwarf star density to that of atomic nuclei.

Tl;dr:
"@
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 60 -temperature 0.7 -top_p 1 -frequency_penalty 0.0 -presence_penalty 1.0

$prompt="Product description: A home milkshake maker`nSeed words: fast, healthy, compact.`nProduct names: HomeShaker, Fit Shaker, QuickShake, Shake Maker`n`nProduct description: A pair of shoes that can fit any foot size.`nSeed words: adaptable, fit, omni-fit."
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 60 -temperature 0.8

$prompt="What is an Cloud Solution Architect?"
Invoke-OpenAIPrompt -prompt $prompt

$prompt="There are many fruits that were found on the recently discovered planet Goocrux. 
There are neoskizzles that grow there, which are purple and taste like candy. 
There are also loheckles, which are a grayish blue fruit and are very tart, a little bit like a lemon. 
Pounits are a bright green color and are more savory than sweet. 
There are also plenty of loopnovas which are a neon pink flavor and taste like cotton candy. 
Finally, there are fruits called glowls, which have a very sour and bitter taste which is acidic and caustic, and a pale orange tinge to them.`n`n
Please make a table summarizing the fruits from Goocrux`n| Fruit | Color | Flavor |`n| Neoskizzles | Purple | Sweet |`n| Loheckles | Grayish blue | Tart |"
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 100 -stop "`n`n"

#Copy long email text to clipboard
$prompt=(Get-Clipboard -Raw)
$prompt=$prompt+"`n`nTl;dr`n`n"
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 100 -stop "`n`n"

$prompt="Write a recipe based on these ingredients and instructions:

Fruit Pie

Ingredients:
Strawberries
Blueberries
Flour
Eggs
Milk"
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 100 

########################################################################################
#Codex

$prompt="#Write me some code"
Invoke-OpenAIPrompt -prompt $prompt -ModelName "code-davinci-002" -max_tokens 100 

$prompt="# Table albums, columns = [AlbumId, Title, ArtistId]
# Table artists, columns = [ArtistId, Name]
# Table media_types, columns = [MediaTypeId, Name]
# Table playlists, columns = [PlaylistId, Name]
# Table playlist_track, columns = [PlaylistId, TrackId]
# Table tracks, columns = [TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice]
# Create a SQL query for all albums with more than 10 tracks"
$json = Invoke-OpenAIPrompt -prompt $prompt -ModelName "code-davinci-002" -max_tokens 2000 -temperature 0.75 -top_p 0.80 -frequency_penalty 0.25 -presence_penalty 0.15 `
        -AsJson

$prompt="Write a for loop counting from 1 to 10 in Python"
Invoke-OpenAIPrompt -prompt $prompt -ModelName "code-davinci-002" -max_tokens 100 

$prompt="# Python 3
def mult_numbers(a, b):
  return a * b

# Unit test
def"
Invoke-OpenAIPrompt -prompt $prompt -ModelName "code-davinci-002" -max_tokens 100 

$prompt="<!-- build a page titled `"Let's Learn about AI`" -->"
Invoke-OpenAIPrompt -prompt $prompt -ModelName "code-davinci-002" -max_tokens 100 -AsJson

$prompt="How long does it take stain to dry?"
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 150


##############################################################################################
# OpenAI Examples
# https://platform.openai.com/examples

#https://platform.openai.com/examples/default-friend-chat
$prompt="
Human: Hello, who are you?
AI: I am an AI created by OpenAI. How can I help you today?
Human: I'd like to cancel my subscription.
AI:
"
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 150 -temperature 0.9 -top_p 1 -frequency_penalty 0.0 -presence_penalty 0.6 -stop @("Human:","AI:") -AsJson
#I apologize for the inconvenience. To cancel your subscription, please contact our customer support team by calling the number provided in your account or by using our web form to submit a request. 
#Thank you for using our service. Is there anything else I can do for you?

#https://platform.openai.com/examples/default-mood-color?lang=python
$prompt=@"
The CSS code for a color like a blue sky at dusk:

background-color: #
"@
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 64 -temperature 0 -stop ";"
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 64 -temperature 0

#https://platform.openai.com/examples/default-qa
$prompt=@"
I am a highly intelligent question answering bot. If you ask me a question that is rooted in truth, I will give you the answer. If you ask me a question that is nonsense, trickery, or has no clear answer, I will respond with "Unknown".

Q: What is human life expectancy in the United States?
A: Human life expectancy in the United States is 78 years.

Q: Who was president of the United States in 1955?
A: Dwight D. Eisenhower was president of the United States in 1955.

Q: Which party did he belong to?
A: He belonged to the Republican Party.

Q: What is the square root of banana?
A: Unknown

Q: How does a telescope work?
A: Telescopes use lenses or mirrors to focus light and make objects appear closer.

Q: Where were the 1992 Olympics held?
A: The 1992 Olympics were held in Barcelona, Spain.

Q: How many squigs are in a bonk?
A: Unknown

Q: Where is the Valley of Kings?
A:
"@
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 100 -temperature 0 -top_p 1 -frequency_penalty 0.0 -presence_penalty 0.0 -stop "`n" 

#https://platform.openai.com/examples/default-grammar
$prompt=@"
Correct this to standard English:

She no went to the market.
"@
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 150

#https://platform.openai.com/examples/default-summarize
$prompt=@"
Summarize this for a second-grade student:

Jupiter is the fifth planet from the Sun and the largest in the Solar System. It is a gas giant with a mass one-thousandth that of the Sun, but two-and-a-half times that of all the other planets in the Solar System combined. Jupiter is one of the brightest objects visible to the naked eye in the night sky, and has been known to ancient civilizations since before recorded history. It is named after the Roman god Jupiter.[19] When viewed from Earth, Jupiter can be bright enough for its reflected light to cast visible shadows,[20] and is on average the third-brightest natural object in the night sky after the Moon and Venus.
"@
Invoke-OpenAIPrompt -prompt $prompt -max_tokens 64 -temperature 0.7 -top_p 1.0 -frequency_penalty 0.0 -presence_penalty 0.0

#https://platform.openai.com/examples/default-openai-api
$prompt=@"
"""
Util exposes the following:
util.openai() -> authenticates & returns the openai module, which has the following functions:
openai.Completion.create(
    prompt="<my prompt>", # The prompt to start completing from
    max_tokens=123, # The max number of tokens to generate
    temperature=1.0 # A measure of randomness
    echo=True, # Whether to return the prompt in addition to the generated completion
)
"""
import util
"""
Create an OpenAI completion starting from the prompt "Once upon an AI", no more than 5 tokens. Does not include the prompt.
"""

"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "code-davinci-002" -max_tokens 64 -temperature 0 -top_p 1.0 -frequency_penalty 0.0 -presence_penalty 0.0 -stop '"""'

#https://platform.openai.com/examples/default-keywords
$prompt=@"
Extract keywords from this text:

Black-on-black ware is a 20th- and 21st-century pottery tradition developed by the Puebloan Native American ceramic artists in Northern New Mexico. Traditional reduction-fired blackware has been made for centuries by pueblo artists. Black-on-black ware of the past century is produced with a smooth surface, with the designs applied through selective burnishing or the application of refractory slip. Another style involves carving or incising designs and selectively polishing the raised areas. For generations several families from Kha'po Owingeh and P'ohwhóge Owingeh pueblos have been making black-on-black ware with the techniques passed down from matriarch potters. Artists from other pueblos have also produced black-on-black ware. Several contemporary artists have created works honoring the pottery of their ancestors.
"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "text-davinci-003" -max_tokens 60 -temperature 0.5 -top_p 1.0 -frequency_penalty 0.8 -presence_penalty 0.0

#https://platform.openai.com/examples/default-ad-product-description
$prompt=@"
Write a creative ad for the following product to run on Facebook aimed at parents:

Product: Learning Room is a virtual environment to help students from kindergarten to high school excel in school.
"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "text-davinci-003" -max_tokens 100 -temperature 0.5 -top_p 1.0 -frequency_penalty 0.0 -presence_penalty 0.0

#https://platform.openai.com/examples/default-spreadsheet-gen
$prompt=@"
A two-column spreadsheet of top science fiction movies and the year of release:

Title |  Year of release
"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "text-davinci-003" -max_tokens 60 -temperature 0.5 -top_p 1.0 -frequency_penalty 0.0 -presence_penalty 0.0

#https://platform.openai.com/examples/default-ml-ai-tutor
$prompt=@"
ML Tutor: I am a ML/AI language model tutor
You: What is a language model?
ML Tutor: A language model is a statistical model that describes the probability of a word given the previous words.
You: What is a statistical model?
"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "text-davinci-003" -max_tokens 60 -temperature 0.3 -top_p 1.0 -frequency_penalty 0.5 -presence_penalty 0.0 -stop "You:"

#https://platform.openai.com/examples/default-tweet-classifier
$prompt=@"
Decide whether a Tweet's sentiment is positive, neutral, or negative.

Tweet: "I loved the new Batman movie!"
Sentiment:
"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "text-davinci-003" -max_tokens 60 -temperature 0 -top_p 1.0 -frequency_penalty 0.5 -presence_penalty 0.0

#https://platform.openai.com/examples/default-sql-request
$prompt=@"
Create a SQL request to find all users who live in California and have over 1000 credits:
"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "text-davinci-003" -max_tokens 60 -temperature 0.3 -top_p 1.0 -frequency_penalty 0.0 -presence_penalty 0.0

#https://platform.openai.com/examples/default-sql-translate
$prompt=@"
### Postgres SQL tables, with their properties:
#
# Employee(id, name, department_id)
# Department(id, name, address)
# Salary_Payments(id, employee_id, amount, date)
#
### A SQL query to list the names of the departments which employed more than 10 employees in the last 3 months
SELECT
"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "code-davinci-002" -max_tokens 150 -temperature 0 -top_p 1.0 -frequency_penalty 0.0 -presence_penalty 0.0 -stop @("#",";")

#https://platform.openai.com/examples/default-js-to-py
$prompt=@"
#JavaScript to Python:
JavaScript: 
dogs = ["bill", "joe", "carl"]
car = []
dogs.forEach((dog) {
    car.push(dog);
});

Python:
"@
Invoke-OpenAIPrompt -prompt $prompt -ModelName "code-davinci-002" -max_tokens 64 -temperature 0 -top_p 1.0 -frequency_penalty 0.0 -presence_penalty 0.0 -stop "#JavaScript to Python"

##############################################################################################

#https://learn.microsoft.com/en-us/azure/cognitive-services/openai/how-to/work-with-code
$prompt=@"
#Table albums, columns = [AlbumId, Title, ArtistId]
#Table artists, columns = [ArtistId, Name]
#Table media_types, columns = [MediaTypeId, Name]
#Table playlists, columns = [PlaylistId, Name]
#Table playlist_track, columns = [PlaylistId, TrackId]
#Table tracks, columns = [TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice]

#Create a query for all albums with more than 10 tracks
SQL:
"@
Invoke-OpenAIPrompt -prompt $prompt `
    -ModelName "code-davinci-002" `
    -max_tokens 64 -stop "#"

##############################################################################################
# https://learn.microsoft.com/en-us/azure/cognitive-services/openai/how-to/chatgpt
# ChatGPT using ChatML
# NOTE: It is preferred to use the Chat Completion instead of ChatML
$prompt=@"
<|im_start|>system
Assistant is a large language model trained by OpenAI.
<|im_end|>
<|im_start|>user
What's the difference between garbanzo beans and chickpeas?
<|im_end|>
<|im_start|>assistant
"@
Invoke-OpenAIPrompt -prompt $prompt `
    -ModelName "gpt-35-turbo" `
    -temperature 0 -top_p 0.95 -max_tokens 350 -frequency_penalty 0 -presence_penalty 0 -stop "<|im_end|>"

$prompt=@"
<|im_start|>system 
Provide some context and/or instructions to the model.
<|im_end|> 
<|im_start|>user 
The user's message goes here
<|im_end|> 
<|im_start|>assistant
"@
Invoke-OpenAIPrompt -prompt $prompt `
    -ModelName "gpt-35-turbo" `
    -temperature 0 -top_p 0.95 -max_tokens 350 -frequency_penalty 0 -presence_penalty 0 -stop "<|im_end|>"

$prompt=@"
<|im_start|>system
Assistant is an intelligent chatbot designed to help users answer their tax related questions. 

Instructions:
- Only answer questions related to taxes. 
- If you're unsure of an answer, you can say "I don't know" or "I'm not sure" and recommend users go to the IRS website for more information.
<|im_end|>
<|im_start|>user
When are my taxes due?
<|im_end|>
<|im_start|>assistant
"@
Invoke-OpenAIPrompt -prompt $prompt `
    -ModelName "gpt-35-turbo" `
    -temperature 0 -top_p 0.95 -max_tokens 350 -frequency_penalty 0 -presence_penalty 0 -stop "<|im_end|>"


$prompt=@"
<|im_start|>system
You are an Xbox customer support agent whose primary goal is to help users with issues they are experiencing with their Xbox devices. You are friendly and concise. You only provide factual answers to queries, and do not provide answers that are not related to Xbox.
<|im_end|>
<|im_start|>user
How much is a PS5?
<|im_end|>
<|im_start|>assistant
I apologize, but I do not have information about the prices of other gaming devices such as the PS5. My primary focus is to assist with issues regarding Xbox devices. Is there a specific issue you are having with your Xbox device that I may be able to help with?
<|im_end|>
<|im_start|>user
What is an elite controller?
<|im_end|>
<|im_start|>assistant
"@
Invoke-OpenAIPrompt -prompt $prompt `
    -ModelName "gpt-35-turbo" `
    -temperature 0 -top_p 0.95 -max_tokens 350 -frequency_penalty 0 -presence_penalty 0 -stop "<|im_end|>"


$qna=@()
$system="You are an Xbox customer support agent whose primary goal is to help users with issues they are experiencing with their Xbox devices. You are friendly and concise. You only provide factual answers to queries, and do not provide answers that are not related to Xbox."
$qna+=@{question="How much is a PS5?";answer="I apologize, but I do not have information about the prices of other gaming devices such as the PS5. My primary focus is to assist with issues regarding Xbox devices. Is there a specific issue you are having with your Xbox device that I may be able to help with?"}
#$qna+=@{question="What is an elite controller?";answer="The Xbox Elite Wireless Controller Series 2 features over 30 new ways to play like a pro, including adjustable-tension thumbsticks, wrap-around rubberized grip, and shorter hair trigger locks."}
#$qna+=@{question="What is a Kinect?";answer="The Kinect is a motion sensing input device that allows users to control and interact with their Xbox 360 without the need to touch a game controller."}
#$qna+=@{question="What is a game pass?";answer="The Xbox Game Pass is a subscription service that provides access to over 100 high-quality games for a low monthly price."}
#$qna+=@{question="What is a game pass ultimate?";answer="The Xbox Game Pass Ultimate is a subscription service that provides access to over 100 high-quality games for a low monthly price, as well as Xbox Live Gold and Xbox Game Pass for PC."}

$keep=3
$list=@()
do
{

    $q = Read-Host "Ask a question"
    if( $q -eq "" ) { break }

    $cnt=0
    for( $i=$qna.Count-1; $i -ge 0; $i-- )
    {
        $list+=$qna[$i]
        $cnt++
        if( $cnt -ge $keep ) { break }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<|im_start|>system")
    [void]$sb.AppendLine($system)
    [void]$sb.AppendLine("<|im_end|>")
    [Array]::Reverse($list)
    foreach( $item in $list )
    {
        [void]$sb.AppendLine("<|im_start|>user")
        [void]$sb.AppendLine($item.question)
        [void]$sb.AppendLine("<|im_end|>")
        [void]$sb.AppendLine("<|im_start|>assistant")
        [void]$sb.AppendLine($item.answer)
        [void]$sb.AppendLine("<|im_end|>")
    }
    [void]$sb.AppendLine("<|im_start|>user")
    [void]$sb.AppendLine($q)
    [void]$sb.AppendLine("<|im_end|>")
    [void]$sb.AppendLine("<|im_start|>assistant")
    $prompt=$sb.ToString()

    $answer = Invoke-OpenAIPrompt -prompt $prompt `
        -ModelName "gpt-35-turbo" `
        -temperature 0 -top_p 0.95 -max_tokens 350 -frequency_penalty 0 -presence_penalty 0 -stop "<|im_end|>"
    Write-Host $answer -ForegroundColor Yellow
    $qna+=@{question=$q;answer=$answer}
}while( $q -ne "exit")

# New version to match python code
$qna=@()
$qna+=@{role="system";content="You are an Xbox customer support agent whose primary goal is to help users with issues they are experiencing with their Xbox devices. You are friendly and concise. You only provide factual answers to queries, and do not provide answers that are not related to Xbox."}
$qna+=@{role="user";content="How much is a PS5?"}
$qna+=@{role="assistant";content="I apologize, but I do not have information about the prices of other gaming devices such as the PS5. My primary focus is to assist with issues regarding Xbox devices. Is there a specific issue you are having with your Xbox device that I may be able to help with?"}
#$qna+=@{question="What is an elite controller?";answer="The Xbox Elite Wireless Controller Series 2 features over 30 new ways to play like a pro, including adjustable-tension thumbsticks, wrap-around rubberized grip, and shorter hair trigger locks."}
#$qna+=@{question="What is a Kinect?";answer="The Kinect is a motion sensing input device that allows users to control and interact with their Xbox 360 without the need to touch a game controller."}
#$qna+=@{question="What is a game pass?";answer="The Xbox Game Pass is a subscription service that provides access to over 100 high-quality games for a low monthly price."}
#$qna+=@{question="What is a game pass ultimate?";answer="The Xbox Game Pass Ultimate is a subscription service that provides access to over 100 high-quality games for a low monthly price, as well as Xbox Live Gold and Xbox Game Pass for PC."}

$keep=3
do
{

    $q = Read-Host "Ask a question"
    if( $q -eq "" ) { break }
    $qna+=@{role="user";content=$q}

    $cnt=0
    $list=@()
    for( $i=$qna.Count-1; $i -ge 0; $i-- )
    {
        $list+=$qna[$i]
        $cnt++
        if( $cnt -ge $keep ) { break }
    }

    $sb = [System.Text.StringBuilder]::new()
    [Array]::Reverse($list)
    foreach( $item in $list )
    {
        [void]$sb.Append("<|im_start|>")
        [void]$sb.AppendLine($item.role)
        [void]$sb.AppendLine("<|im_end|>")
    }
    [void]$sb.AppendLine("<|im_start|>assistant")
    $prompt=$sb.ToString()

    $answer = Invoke-OpenAIPrompt -prompt $prompt `
        -ModelName "gpt-35-turbo" `
        -temperature 0 -top_p 0.95 -max_tokens 350 -frequency_penalty 0 -presence_penalty 0 -stop "<|im_end|>"
    Write-Host $answer -ForegroundColor Yellow
    $qna+=@{role="assistant";content=$answer}
}while( $q -ne "exit")

# 
$messages=@()
$prompt=@"
Assistant helps the company employees with their healthcare plan questions, and questions about the employee handbook. Be brief in your answers.
Answer ONLY with the facts listed in the list of sources below. If there isn't enough information below, say you don't know. Do not generate answers that don't use the sources below. If asking a clarifying question to the user would help, ask the question.
Each source has a name followed by colon and the actual information, always include the source name for each fact you use in the response. Use square brakets to reference the source, e.g. [info1.txt]. Don't combine sources, list each source separately, e.g. [info1.txt][info2.pdf].


Sources:
employee_handbook-3.pdf: They will also provide you with an opportunity to discuss your goals and objectives for the upcoming year. Performance reviews are a two -way dialogue between managers and employees. We encourage all employees to be honest and open during the review process, as it is an important opportunity to discuss successes and challenges in the workplace. We aim to provide positive and constructive feedback during performance reviews. This feedback should be used as an opportunity to help employees develop and grow in their roles. Employees will receive a written summary of their perfor mance review which will be discussed during the review session. This written summary will include a rating of the employee’s performance, feedback, and goals and objectives for the upcoming year. We understand that performance reviews can be a stressful p rocess. We are committed to making sure that all employees feel supported and empowered during the process. We encourage all employees to reach out to their managers with any questions or concerns they may have.
employee_handbook-2.pdf: Respect: We treat all our employees, c ustomers, and partners with respect and dignity. 6. Excellence: We strive to exceed expectations and provide excellent service. 7. Accountability: We take responsibility for our actions and hold ourselves and others accountable for their performance. 8. Co mmunity: We are committed to making a positive impact in the communities in which we work and live. Performance Reviews Performance Reviews at Contoso Electronics At Contoso Electronics, we strive to ensure our employees are getting the feedback they need to continue growing and developing in their roles. We understand that performance reviews are a key part of this process and it is important to us that they are conducted in an effective and efficient manner. Performance reviews are conducted annually a nd are an important part of your career development. During the review, your supervisor will discuss your performance over the past year and provide feedback on areas for improvement. They will also provide you with an opportunity to discuss your goals and objectives for the upcoming year.
Northwind_Standard_Benefits_Details-14.pdf: These services include any charges that are not related to the diagnosis and treatment of an illness or injury. For example, non -covered services like cosmetic surgery, non-prescription drugs, or services that were p rovided outside of the Northwind Health network will not count toward the out -of-pocket maximum. It's important for employees to remember that the out -of-pocket maximum will reset at the start of the calendar year. This means that any out -of-pocket expense s paid during the previous year will not carry over to the new year. To keep track of their out -of-pocket expenses, employees should review their insurance statements regularly. They should also review their Explanation of Benefits (EOB) documents to make sure that all of their expenses have been properly accounted for. This can help them to stay on top of their out -of-pocket expenses and avoid exceeding the maximum. Employees should also be aware that the out -of-pocket maximum does not include the cost of premiums.
"@
$messages+=@{role="system";content=$prompt}
$messages+=@{role="user";content="Can you tell me about performance reviews?"}
Invoke-OpenAIChatGPT -Messages $messages


$messages=@()
$messages+=@{role="system";content="The system is an AI assistant that helps people find information."}
$messages+=@{role="user";content="Does Azure OpenAI support customer managed keys"}
Invoke-OpenAIChatGPT -Messages $messages -AsJson

$messages=@()
$messages+=@{role="system";content="Assistant is a large language model trained by OpenAI."}
$messages+=@{role="user";content="What's the difference between garbanzo beans and chickpeas?"}
Invoke-OpenAIChatGPT -Messages $messages

$prompt=@"
Assistant is an intelligent chatbot designed to help users answer their tax related questions. 

Instructions:
- Only answer questions related to taxes. 
- If you're unsure of an answer, you can say "I don't know" or "I'm not sure" and recommend users go to the IRS website for more information.
"@
$messages+=@{role="system";content=$prompt}
$messages+=@{role="user";content="When are my taxes due?"}
Invoke-OpenAIChatGPT -Messages $messages

$prompt=@"
Assistant is an intelligent chatbot designed to help users answer technical questions about Azure OpenAI Serivce. Only answer questions using the context below and if you're not sure of an answer, you can say "I don't know".

Context:
- Azure OpenAI Service provides REST API access to OpenAI's powerful language models including the GPT-3, Codex and Embeddings model series.
- Azure OpenAI Service gives customers advanced language AI with OpenAI GPT-3, Codex, and DALL-E models with the security and enterprise promise of Azure. Azure OpenAI co-develops the APIs with OpenAI, ensuring compatibility and a smooth transition from one to the other.
- At Microsoft, we're committed to the advancement of AI driven by principles that put people first. Microsoft has made significant investments to help guard against abuse and unintended harm, which includes requiring applicants to show well-defined use cases, incorporating Microsoft’s principles for responsible AI use
"@
$messages+=@{role="system";content=$prompt}
$messages+=@{role="user";content="What is Azure OpenAI Service?"}
Invoke-OpenAIChatGPT -Messages $messages

#Few shot
$messages=@()
$messages+=@{role="system";content="Assistant is an intelligent chatbot designed to help users answer their tax related questions."}
$messages+=@{role="user";content="When do I need to file my taxes by?"}
$messages+=@{role="assisstant";content="In 2023, you will need to file your taxes by April 18th. The date falls after the usual April 15th deadline because April 15th falls on a Saturday in 2023. For more details, see https://www.irs.gov/filing/individuals/when-to-file"}
$messages+=@{role="user";content="How can I check the status of my tax refund?"}
$messages+=@{role="assisstant";content="You can check the status of your tax refund by visiting https://www.irs.gov/refunds"}

#Prompt with a specific return
$prompt=@"
You are an assistant designed to extract entities from text. Users will paste in a string of text and you will respond with entities you've extracted from the text as a JSON object. Here's an example of your output format:
{
   "name": "",
   "company": "",
   "phone_number": ""
}
"@
$messages+=@{role="system";content=$prompt}
$messages+=@{role="user";content="Hello. My name is Robert Smith. I’m calling from Contoso Insurance, Delaware. My colleague mentioned that you are interested in learning about our comprehensive benefits policy. Could you give me a call back at (555) 346-9322 when you get a chance so we can go over the benefits?"}
Invoke-OpenAIChatGPT -Messages $messages

####################################
#$question="What is included in my Northwind Health Plus plan that is not in standard?"
#$question = "Does my plan cover dental exams?"
$question = "Does my plan cover eye exams?"
#$question = "Are free drugs included?"
#$question = "¿Qué sucede en una evaluación de desempeño?"

#¿Cuándo se realizan las evaluaciones de rendimiento?
#Add to the prompt: if someone asks a question that is not in english, convert it to english BEFORE sources
# Invoke-SearchRequest -Method GET -requestUri "https://$searchServiceName.search.windows.net/indexes?api-version=2020-06-30&`$select=name"
$body = @"
{
    "queryType":"semantic",
    "search": "$question",
    "queryLanguage":"en-us"
}
"@
$api="2020-06-30-Preview"
$rt = Invoke-SearchRequest -Method POST -requestUri "https://$searchServiceName.search.windows.net/indexes/$searchIndex/docs/search?api-version=$api&`$top=3" -Body $body

$addOn=""
$addOn="if someone asks a question that is not in english, convert it to english"

$src = [System.Text.StringBuilder]::new()
[void]$src.AppendLine("Assistant helps the company employees with their healthcare plan questions and employee handbook questions. Answer ONLY with the facts listed in the list of sources below. If there isn't enough information below, say you don't know. Do not generate answers that don't use the sources below. If asking a clarifying question to the user would help, ask the question. Each source has a name followed by colon and the actual information, always include the source name for each fact you use in the response. Use square brakets to reference the source, e.g. [info1.txt]. Don't combine sources, list each source separately, e.g. [info1.txt][info2.pdf].")
[void]$src.Append("`n`n")
if( "" -ne $addOn )
{
    [void]$src.AppendLine($addOn)
    [void]$src.Append("`n`n")
}
[void]$src.AppendLine("Sources:")
foreach($val in $rt.value)
{
    [void]$src.Append($val.sourcepage)
    [void]$src.AppendLine(":  ")
    [void]$src.AppendLine($val.content.Replace("`n","").Trim())
}
$messages=@()
$messages+=@{role="system";content=$src.ToString()}
$messages+=@{role="user";content=$question}
Invoke-OpenAIChatGPT -Messages $messages


####################################
#$question="Where are properties near Texas?"
$question="Are there any properties with a view of the mountains and a pool?"
#$question="Are there any properties with a pool?"

$body = @"
{
    "queryType":"semantic",
    "search": "$question",
    "queryLanguage":"en-us",
    "searchFields":"description",
    "top":5
}
"@
$api="2020-06-30-Preview"
$rt = Invoke-SearchRequest -Method POST -requestUri "https://$searchServiceName.search.windows.net/indexes/realestate-us-sample-index/docs/search?api-version=$api" -Body $body


$src = [System.Text.StringBuilder]::new()
[void]$src.Append("Assistant helps find housing. Answer ONLY with the facts listed in the list of sources below. If there isn't enough information below, say you don't know.")
[void]$src.Append("Do not generate answers that don't use the sources below. If asking a clarifying question to the user would help, ask the question.")
[void]$src.Append("Each source has a listingId,number,street,city,region,countryCode,thumbNail followed by colon and the description, always include the description for each property you use in the response.")
[void]$src.AppendLine("Respond with the description and a link to the thumbnail. Example: nice house [OMAGS123](image.jpg) for each result")
# [void]$src.AppendLine("Use href with a link to the thumbNail that includes the city and, e.g. <a href=`"https://img.jpg`">999 S 168th street</a>. Don't combine sources, list each source separately, e.g. [info1.jpg][info2.jpg].")
[void]$src.Append("`n`n")
[void]$src.AppendLine("Sources:")
foreach($val in $rt.value)
{
    [void]$src.AppendFormat("{0},{1},{2},{3},{4},{5},{6}",$val.listingId,$val.number,$val.street,$val.city,$val.region,$val.countryCode,$val.thumbNail)
    [void]$src.Append(":  ")
    [void]$src.AppendLine($val.description.Replace("`n","").Trim())
}
$messages=@()
$messages+=@{role="system";content=$src.ToString()}
$messages+=@{role="user";content=$question}
Invoke-OpenAIChatGPT -Messages $messages


####################################
$messages=@()
$messages+=@{role="system";content="Assistant helps answer questions about the leaders at Microsoft and no other companies. If a question is asked about another company ignore it"}
#$messages+=@{role="user";content="Who is the CEO of Microsoft?"}
#$ans=Invoke-OpenAIChatGPT -Messages $messages
#$messages+=@{role="assisstant";content=$ans}
$messages+=@{role="user";content="What sports does he love?"}
Invoke-OpenAIChatGPT -Messages $messages


##############################
$question="Are there any properties with a view of the mountains and a pool?"
#$question="Are there any properties with a pool?"

$body = @"
{
    "queryType":"semantic",
    "search": "$question",
    "queryLanguage":"en-us",
    "searchFields":"description",
    "top":5
}
"@
$api="2020-06-30-Preview"
$rt = Invoke-SearchRequest -Method POST -requestUri "https://$searchServiceName.search.windows.net/indexes/realestate-us-sample-index/docs/search?api-version=$api" -Body $body


$src = [System.Text.StringBuilder]::new()
[void]$src.Append("Assistant helps find housing. Answer ONLY with the facts listed in the list of sources below. If there isn't enough information below, say you don't know.")
[void]$src.Append("Do not generate answers that don't use the sources below. If asking a clarifying question to the user would help, ask the question.")
[void]$src.Append("Each source has a listingId,number,street,city,region,countryCode,thumbNail followed by colon and the description, always include the description for each property you use in the response.")
[void]$src.AppendLine("Respond with the description and a link to the thumbnail. Example: nice house [OMAGS123](image.jpg) for each result")
# [void]$src.AppendLine("Use href with a link to the thumbNail that includes the city and, e.g. <a href=`"https://img.jpg`">999 S 168th street</a>. Don't combine sources, list each source separately, e.g. [info1.jpg][info2.jpg].")
[void]$src.Append("`n`n")
[void]$src.AppendLine("Sources:")
foreach($val in $rt.value)
{
    [void]$src.AppendFormat("{0},{1},{2},{3},{4},{5},{6}",$val.listingId,$val.number,$val.street,$val.city,$val.region,$val.countryCode,$val.thumbNail)
    [void]$src.Append(":  ")
    [void]$src.AppendLine($val.description.Replace("`n","").Trim())
}
$messages=@()
$messages+=@{role="system";content=$src.ToString()}
$messages+=@{role="user";content=$question}
Invoke-OpenAIChatGPT -Messages $messages

##################################
# SQL Harness
##################################
$ServerName=$cfg["SQL_SERVER"]
$DatabaseName=$cfg["SQL_DB_NAME"]
$User=$cfg["SQL_USER"]
$Password=$cfg["SQL_PWD"]


$cols = Invoke-SqlCmd -ServerInstance $ServerName -Database $DatabaseName -UserName $User -Password $Password -Query "SELECT TABLE_SCHEMA,TABLE_NAME,COLUMN_NAME,DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS"

$src = [System.Text.StringBuilder]::new()
foreach($tbl in ($cols | Select-Object TABLE_NAME -Unique).TABLE_NAME)
{
    #$sql = $("Table {0}, columns = [{1}]" -f $tbl, (($cols | Where-Object TABLE_NAME -eq $tbl | Select-Object -ExpandProperty COLUMN_NAME) -join ","))
    #$sql = $("{0} = [{1}]" -f $tbl, (($cols | Where-Object TABLE_NAME -eq $tbl | Select-Object @{name="result";e={$_.COLUMN_NAME}}) -join ","))
    $sql = $("{0} = [{1}]" -f $tbl, (($cols | Where-Object TABLE_NAME -eq $tbl | Select-Object @{n="result";e={"{0} ({1})" -f $_.COLUMN_NAME,$_.DATA_TYPE}}).result -join ","))
    
    [void]$src.AppendLine($sql)
}

$prompt=@"
Given the following tables and columns with data types:
$($src.ToString())
#Create a SQL query for total sales for each product category where the year = 2002
"@

Write-Host $prompt -ForegroundColor Yellow

Invoke-OpenAIPrompt -prompt $prompt `
    -ModelName "code-davinci-002" `
    -temperature 0 -max_tokens 250 -stop "#"

##############################
# Bing Search
##############################

$question="What are the best places to visit in Barcelona Spain?"
$params = "q={0}&mkt=en-us&safeSearch=Moderate&textDecoration=True&textFormat=HTML" -f [System.Web.HttpUtility]::UrlEncode($question)

Invoke-SearchBing -params $params

##############################
# Bing Search specific site
##############################
$site="learn.microsoft.com/en-us/azure"
#$question="Rbac options in azure openai"
$question="Query limits in azure openai"
$question="Is GPT-4 available in azure openai"


$site="learn.microsoft.com/en-us/azure"
$question="In power bi, if I work for another orgnaization am I covered under premium licensing?"

$params = "q={0}+site:{1}&mkt=en-us&safeSearch=Moderate&textDecoration=True&textFormat=HTML" -f [System.Web.HttpUtility]::UrlEncode($question),[System.Web.HttpUtility]::UrlEncode($site)
Invoke-SearchBing -params $params

# Search for Power BI

$site="learn.microsoft.com/en-us/power-bi"
$question="In power bi, if I work for another orgnaization am I covered under premium licensing?"

$params = "q={0}+site:{1}&mkt=en-us&safeSearch=Moderate&textDecoration=True&textFormat=HTML" -f [System.Web.HttpUtility]::UrlEncode($question),[System.Web.HttpUtility]::UrlEncode($site)
Invoke-SearchBing -params $params


##############
# Chat without context
##############
$messages=@()
$messages+=@{role="system";content="Assistant is a large language model trained by OpenAI."}
$messages+=@{role="user";content="Who is the CEO of Microsoft?"}
Invoke-OpenAIChatGPT -Messages $messages
<#
<|im_start|>system
Assistant is a large language model trained by OpenAI.
<|im_end|>
<|im_start|>user
Who is the CEO of Microsoft?
<|im_end|>
<|im_start|>assistant

Response: 
As of 2021, the CEO of Microsoft is Satya Nadella.
#>


$messages=@()
$messages+=@{role="system";content="Assistant is a large language model trained by OpenAI."}
$messages+=@{role="user";content="What sports does he love?"}
Invoke-OpenAIChatGPT -Messages $messages
<#
<|im_start|>system
Assistant is a large language model trained by OpenAI.
<|im_end|>
<|im_start|>user
What sports does he love?
<|im_end|>
<|im_start|>assistant

As an artificial intelligence language model, I don't have personal preferences or emotions like humans do, so I don't "love" anything. However, I can provide information about different sports if you're interested. What sport would you like to know more about?

#>

$messages=@()
$messages+=@{role="system";content="Assistant is a large language model trained by OpenAI."}
$messages+=@{role="user";content="Who is the CEO of Microsoft?"}
$messages+=@{role="assistant";content="As of 2021, the CEO of Microsoft is Satya Nadella."}
$messages+=@{role="user";content="What sports does he love?"}
Invoke-OpenAIChatGPT -Messages $messages
# I'm not sure about Satya Nadella's personal interests in sports, as that information is not widely available. However, he has mentioned in interviews that he is a big cricket fan, which is a popular sport in his home country of India.
