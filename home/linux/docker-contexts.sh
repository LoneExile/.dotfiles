# shellcheck shell=bash
# ensure_docker_context DOCKER NAME HOST [current]: make the docker context NAME with the endpoint HOST, once.
# Sourced by the Home Manager activation of home/linux/agent.nix, which supplies `run` (it prints instead of acting on a dry run).
# Contexts replace DOCKER_HOST: while DOCKER_HOST is exported, `docker context use`, DOCKER_CONTEXT and lazydocker's context
# lookup are all ignored, so nothing exports it and the local daemon is the context `rootless` (measured, see the README).
#   - NAME missing: created; with `current` it is also made the current context, but only now, at creation: a later
#     `docker context use` of the user is never undone by an activation (Home Manager runs at every switch and boot).
#   - NAME there with this HOST: nothing changes. With another HOST: the endpoint is updated, the current context is not touched.
#   - docker fails: said on stderr, the activation goes on (it never fails a switch). Nothing here contacts a daemon.
docker_contexts_quiet() { "$@" >/dev/null 2>&1; }

ensure_docker_context() {
  local docker=$1 name=$2 host=$3 current=${4:-} have
  if have=$("$docker" context inspect --format '{{.Endpoints.docker.Host}}' "$name" 2>/dev/null); then
    [ "$have" = "$host" ] ||
      run docker_contexts_quiet "$docker" context update "$name" --docker "host=$host" ||
      printf 'docker-contexts: could not update the context %s to %s\n' "$name" "$host" >&2
    return 0
  fi
  if run docker_contexts_quiet "$docker" context create "$name" --docker "host=$host"; then
    [ "$current" != current ] || run docker_contexts_quiet "$docker" context use "$name" ||
      printf 'docker-contexts: could not make the context %s current\n' "$name" >&2
  else
    printf 'docker-contexts: could not create the context %s (%s)\n' "$name" "$host" >&2
  fi
  return 0
}
