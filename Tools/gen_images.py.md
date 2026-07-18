# gen_images.py

The image generator used by SunflowerDeck lives in the session scratchpad
(not committed). It reads a JSON manifest of {name, prompt, size} and calls
OpenAI gpt-image-1, caching by prompt hash so re-runs are free. It expects
OPENAI_API_KEY in the environment and uses /etc/ssl/cert.pem for TLS (system
Python has no bundled CA roots). SunflowerDeck reads the resulting PNGs from
an images directory passed as its second argument.
