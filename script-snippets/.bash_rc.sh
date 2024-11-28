alias gs='git status'
alias k='kubectl'
alias pods='kubectl get pods -w'
alias pod='kubectl get pods -w'

function gsync(){
  UPSREAM_BRANCH=$1
  UPSREAM_BRANCH=${UPSREAM_BRANCH:-master}
  if [[ "$(git remote)" == *"upstream"* ]]; then
    git checkout $UPSREAM_BRANCH && git pull upstream $UPSREAM_BRANCH && git push origin $UPSREAM_BRANCH
  else
    git checkout $UPSREAM_BRANCH && git pull
  fi
}

function kuse(){
  CLS=$1
  if [[ ! -z "$CLS" ]]; then
    export KUBECONFIG=~/.kube/${CLS}.config
  else
    FILE=$(ls ~/.kube/*config | gum filter --placeholder 'select a config')
    if [[ ! -z "$FILE" ]]; then  export KUBECONFIG=$FILE; fi
  fi
}

function ktx(){
    CTX=$(kubectl config get-contexts -o name | gum filter --placeholder 'select a context')
    if [[ ! -z "$CTX" ]]; then  kubectl config use-context "$CTX"; fi
}

function kls(){
  CTX=$(kubectl config get-contexts -o name | gum filter --placeholder 'select a context...')
  if [[ ! -z "$CTX" ]]; then  kubectl config use-context $CTX; fi
}
function kcd(){
  NS=$1
  if [[ -z "$NS" ]]; then
     NS=$(kubectl get ns -o Name | cut -d '/' -f 2 | gum filter --placeholder 'select a namespace...')
  fi
  if [[ ! -z "$NS" ]]; then
    kubectl config set-context --current --namespace $NS
  fi
}
function klog(){
  CONTAINER=$(kubectl get pod -o json "$@" | jq -r '.items[] |.status.initContainerStatuses[]?.pod =.metadata.name | .status.containerStatuses[]?.pod =.metadata.name | [.status.containerStatuses, .status.initContainerStatuses] | flatten | .[] |  select(.state.running.startedAt != null or .state.terminated.startedAt != null) | .pod + " " + .name + " " + (.state.terminated.reason? //"Running") ' | column -t | gum filter --placeholder 'select container...')

  if [[ ! -z "$CONTAINER" ]]; then
    POD=$(echo "$CONTAINER" | awk '{print $1}')
    if [[ ! -z "$@" ]]; then
      NS=$(kubectl get pod  "$@" -o=jsonpath="{.items[?(@.metadata.name=='$POD')].metadata.namespace}")
    else
      NS=$(kubectl config view --minify -o jsonpath='{..namespace}')
      if [[ -z "$NS" ]]; then
        NS=default
      fi
    fi
    kubectl -n "$NS" logs $POD -c $(echo "$CONTAINER" | awk '{print $2}') --tail 200 -f
  else
    >&2 echo "No pods to extract logs"
  fi
}

function netshoot(){
  NS=$1
  if [[ "$NS" == "" ]]; then
    NS=kuma-demo
  fi

  EXISTING=$(kubectl -n $NS get pods mycurlpod -o Name || true)
  if [[ "$EXISTING" != "" ]]; then
    kubectl -n $NS exec -it mycurlpod -c mycurlpod -- bash
  else
    kubectl run -n $NS mycurlpod --image=nicolaka/netshoot -i --tty -- bash
  fi
}

function next_available_port(){
  START_PORT=5681
  if [[ ! -z "$1" ]]; then
    START_PORT=$1
  fi
  END_PORT=$((START_PORT+1000))

  PORT=$START_PORT
  while [[ "$PORT" -le "$END_PORT" ]]; do
    if [[ $(uname) == "Darwin" ]]; then
        lsof -i:"$PORT" >/dev/null 2>&1
        # 0 means port is in use (found in result)
        if [[ $? -ne 0 ]]; then
          break
        fi
    fi

    if [[ $(uname) == "Linux" ]]; then
        nc -z localhost "$PORT" 2>/dev/null
        # 0 means port is in use (connect successfully)
        if [[ $? -ne 0 ]]; then
          break
        fi
    fi

    ((PORT++))
  done
  echo $PORT
}

function kmesh_license_add(){
  if [[ -z "$KMESH_LICENSE" ]]; then
    echo "Please specify license file path as env variable 'KMESH_LICENSE'"
    exit 1
  fi

  SYSTEM_NS=$(kubectl get namespace kong-mesh-global -o Name 2>/dev/null || true)
  if [[ ! -z "$SYSTEM_NS" ]]; then
    SYSTEM_NS=kong-mesh-global
  else
    SYSTEM_NS=kong-mesh-system
  fi

  kubectl -n $SYSTEM_NS create secret generic kong-mesh-license --from-file=$KMESH_LICENSE 
  kubectl -n $SYSTEM_NS patch deploy/kong-mesh-control-plane --type json --patch '[{"op": "add", "path": "/spec/template/spec/containers/0/env/0", "value":{ "name": "KMESH_LICENSE_INLINE", "valueFrom": {"secretKeyRef": {"name": "kong-mesh-license", "key": "license.json"}}   }}]'
}

function kuma_cp_port_forward(){
  IS_KM=$(kubectl get namespace | grep kong-mesh)
  if [[ -z "$IS_KM" ]]; then
    PRODUCT=kuma
  else
    PRODUCT=kong-mesh
  fi

  CP_NS=$1
  if [[ -z "$CP_NS" ]]; then
    CP_NS=$(kubectl get namespace ${PRODUCT}-global -o Name 2>/dev/null || true)
    if [[ ! -z "$CP_NS" ]]; then
      CP_NS=${PRODUCT}-global
    else
      CP_NS=${PRODUCT}-system
    fi
  fi

  PORT=$(next_available_port 5681)
  echo "$PORT --> svc/${PRODUCT}-control-plane:5681 -n $CP_NS"
  kubectl -n $CP_NS port-forward svc/${PRODUCT}-control-plane $PORT:5681
}

alias klogs=klog
alias day='cd ~/go/src/github.com/jijiechen/kong-workspace/day'
alias kuma='cd ~/go/src/github.com/jijiechen/kuma'
alias km='cd ~/go/src/github.com/Kong/kong-mesh'

alias kuma0='export KUBECONFIG=~/.kube/kind-kuma-config'
alias kuma1='export KUBECONFIG=~/.kube/kind-kuma-1-config'
alias kuma2='export KUBECONFIG=~/.kube/kind-kuma-2-config'

alias preview="$HOME/go/src/github.com/jijiechen/kong-workspace/kong-mesh/preview-source.sh"
alias preview-release="$HOME/go/src/github.com/jijiechen/kong-workspace/kong-mesh/preview-release.sh"

alias clera='clear'
alias pdos='pods'

export PATH=$HOME/go/bin:$HOME/kong-mesh-2.8.1/bin:$HOME/.kuma-dev/kuma-master/bin:$HOME/.local/bin:$PATH
if type crcd >/dev/null 2>&1 ; then
  eval $(crc oc-env)
fi

export GOPRIVATE="github.com/Kong/*"
export NAP_CONFIG="~/.nap/config.yaml"
export GIT_PERSONAL_ORG=jijiechen

# remove "full path" from bash prompt on ubuntu
if [[ -z "$ZSH" ]]; then
export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$ '
fi

git config --global alias.co checkout
git config --global alias.chekcout checkout
git config --global alias.st status
git config --global alias.br branch
git config --global alias.cm 'commit -s'
function br(){
  BR=$(git --no-pager branch | gum filter --placeholder 'select a branch')
  if [[ "${BR:0:2}" != '* ' ]]; then
    git checkout $(echo $BR | tr -d ' ')
  fi
}