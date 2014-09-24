package main

import (
  "fmt"
  "os"
  "os/exec"
  "flag"
  "io/ioutil"

  "gopkg.in/yaml.v1"
)

type MinionConfig struct {
  Master []string
}

const (
  bootstrapSalt     = "/usr/bin/wget -O- https://bootstrap.saltstack.com | sudo sh -s --"
  installFromGit    = "-P git 2014.7"
  minionConfig      = "/etc/salt/minion"
  masterConfig      = "/etc/salt/master"
  acceptAllKeys     = "sudo salt-key --accept-all --yes"
  removeOldKey      = "sudo rm -rf /etc/salt/pki/minion/minion_master.pub"
  restartMaster     = "sudo service salt-minion restart"
  restartMinion     = "sudo service salt-master restart"
)

// function takes string command and string slice of args
// returns result or exits with error
func runCmd(cmd string, args []string) (res []byte) {
  res, err := exec.Command(cmd, args...).Output()
  fmt.Printf("cmd: %s", args)
  if err != nil {
    fmt.Fprintf(os.Stderr, "error: %v\n", err)
    os.Exit(1)
  }
  return res
}

// parse yaml file to struct
// return MinionConfig struct
func parseConfig(data []byte) (*MinionConfig) {
  m := MinionConfig{}
  err := yaml.Unmarshal(data, &m)
  if err != nil {
    fmt.Fprintf(os.Stderr, "error: %v\n", err)
    os.Exit(1)
  }
  return &m
}

// return dump of MinionConfig
func dumpConfig(m *MinionConfig) ([]byte, error) {
  d, err := yaml.Marshal(&m)  
  if err != nil {
    fmt.Fprintf(os.Stderr, "error: %v\n", err)
    return nil,err
  }
  return d,nil
}

// add Master to MinonConfig
func (m *MinionConfig) addMaster(s string) {
  m.Master = append([]string{s}, m.Master...)
}

func main() {
  // parse arguments
  installType := flag.String("type", "", "install type master/minion/both")
  masterIP    := flag.String("master", "", "master IP")
  flag.Parse()

  args := []string{"-c", bootstrapSalt}
  switch *installType {
  case "master":
    args = append(args, "-M -N")
  case "both":
    args = append(args, "-M")
  case "minion":
  default:
    fmt.Println("Missing parameters:")
    flag.PrintDefaults()
    fmt.Println()
    os.Exit(1)
  }

  res := runCmd("bash", args)
  data, err := ioutil.ReadFile(minionConfig)
  if err != nil {
    panic(err)
  }
  cfg := parseConfig(data) // parse yaml into struct
  cfg.addMaster(*masterIP) // add master to minion
  dump,err := dumpConfig(cfg)
  if err != nil {
    panic(err)
  }
  e := ioutil.WriteFile(minionConfig, dump, 0644)
  if e != nil {
    panic(e)
  }
  fmt.Printf("Result: %s", res)
  
}