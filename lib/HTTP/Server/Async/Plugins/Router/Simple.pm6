class HTTP::Server::Async::Plugins::Router::Simple {
  has @.routes;

  method hook($server) {
    $server.handler(-> |args { $.handler(|args); });
  }

  method handler($request,$response) {
    my ($promise, $result);
    for @.routes -> $route {
      next if Any !~~ $route<method>.WHAT && $route<method>.lc ne $request.method.lc;
      given $route<route> {
        when .WHAT ~~ Regex {
          next unless $request.uri ~~ $route<route>; 
        };
        default {
          next unless $request.uri eq $route<route>;
        }
      };
      $promise = $route<sub>($request,$response);
      await $promise if $promise ~~ Promise;
      $result = ($promise ~~ Promise && $promise.status ~~ Kept) || ($promise ~~ Bool && $promise);
      return False if !$result;
    }
    True;
  }

  method !push($method, $route, $sub) {
    @.routes.push({
      method   => $method,
      route    => $route,
      sub      => $sub,
    });
  }

  method all(*@routes) {
    for @routes -> $route {
      self!push(Nil, $route.key, $route.value);
    }
  }

  method get(*@routes) {
    for @routes -> $route {
      self!push('get', $route.key, $route.value);
    }
  }

  method put(*@routes) {
    for @routes -> $route {
      self!push('put', $route.key, $route.value);
    }
  }

  method post(*@routes) {
    for @routes -> $route {
      self!push('post', $route.key, $route.value);
    }
  }

  method delete(*@routes) {
    for @routes -> $route {
      self!push('delete', $route.key, $route.value);
    }
  }
}
