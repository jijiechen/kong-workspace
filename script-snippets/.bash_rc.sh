alias gs='git status'
alias k='kubectl'
alias pods='kubectl get pods -w'
alias pod='kubectl get pods -w'

function kuse(){
  CLS=$1
  if [[ ! -z "$CLS" ]]; then
    export KUBECONFIG=~/.kube/${CLS}.config
  else
    FILE=$(ls ~/.kube/*config | gum filter --placeholder 'select a config')
    if [[ ! -z "$FILE" ]]; then  export KUBECONFIG=$FILE; fi
  fi
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

alias klogs=klog
alias km='cd ~/go/src/github.com/Kong/kong-mesh'
alias kmu='cd ~/go/src/github.com/Kong/kong-mesh-gui'
alias kmesh='cd ~/go/src/github.com/Kong/kong-mesh'

alias kuma='cd ~/go/src/github.com/jijiechen/kuma'
alias kumu='cd ~/go/src/github.com/jijiechen/kuma-gui'


alias kuma0='export KUBECONFIG=~/.kube/kind-kuma-config'
alias kuma1='export KUBECONFIG=~/.kube/kind-kuma-1-config'
alias kuma2='export KUBECONFIG=~/.kube/kind-kuma-2-config'


alias clera='clear'
alias pdos='pods'


export PATH=$HOME/go/bin:$HOME/kong-mesh-2.5.1/bin:$HOME/.kuma-dev/kuma-master/bin:$PATH


export GOPRIVATE="github.com/Kong/*"
export NAP_CONFIG="~/.nap/config.yaml"