/**
 * Declare minimal interfaces for properies that used in Lambda
 */
interface RequestBody {
  words: string;
}

interface ResponseMeta {
  ip_addr: string;
  user_agent: string;
}

interface ResponseBody {
  original: string;
  reversed: string | null;
  meta: ResponseMeta;
}

interface LambdaEvent {
  body: string;
}

interface HttpContext {
  sourceIp: string;
  userAgent: string;
}

interface LambdaContextHttp {
  identity: HttpContext;
}

/**
 * Main handler for Lambda event and request context
 */
async function handler(lambda_event: LambdaEvent, lambda_context: LambdaContextHttp) {
  // Get request body
  let body: RequestBody = JSON.parse(lambda_event.body);
  let response: ResponseBody = {
    reversed: null,
    original: body.words,
    meta: {
      ip_addr: lambda_context.identity.sourceIp,
      user_agent: lambda_context.identity.userAgent
    }
  };

  try {
    response.reversed = body.words.split('').reverse().join('');
  } catch (e) {}

  return JSON.stringify(response);
}

async function lambda_main_loop()
{
  const AWS_LAMBDA_RUNTIME_API = Deno.env.get('AWS_LAMBDA_RUNTIME_API');
  const LAMBDA_BASE_URL = "http://" + AWS_LAMBDA_RUNTIME_API + "/2018-06-01/runtime/invocation";
  let resp: Response | null = null;

  while (true) {
    try {
      resp = await fetch(LAMBDA_BASE_URL + "/next", {
          headers: {
              'Content-Type': 'application/json'
          }
      });
      const evt = await resp.json();
      const invocation_id = resp.headers.get('Lambda-Runtime-Aws-Request-Id');
      const http_context = {
        identity: {
          sourceIp: evt.requestContext.http.sourceIp,
          userAgent: evt.requestContext.http.userAgent,
        }
      }
      const handler_resp = await handler(evt, http_context);

      resp = await fetch(LAMBDA_BASE_URL + "/" + invocation_id + "/response", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: handler_resp
      });

      if (!resp.ok) { console.error(resp) };
    } catch (e) {
      console.error(e);
    }
  }
}

// Run from AWS Lambda
if (Deno.env.get('AWS_LAMBDA_RUNTIME_API')) {
  lambda_main_loop();
}

// Run from CLI
if (!Deno.env.get('AWS_LAMBDA_RUNTIME_API')) {
  const decoder = new TextDecoder('utf-8');
  const json_input = JSON.parse(decoder.decode(Deno.readFileSync('./event.json')));
  // console.log(json_input);

  const evt = {
    body: json_input.body
  };

  const ctx = {
    identity: {
      sourceIp: json_input.requestContext.http.sourceIp,
      userAgent: json_input.requestContext.http.userAgent
    }
  };

  const output = await handler(evt, ctx);
  console.log(output);
}