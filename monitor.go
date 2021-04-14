package main

import (
	"log"
	"os"

	docker "github.com/fsouza/go-dockerclient"
)

func main() {
	cli, err := docker.NewClientFromEnv()
	if err != nil {
		log.Fatal(err)
	}

	listener := make(chan *docker.APIEvents)
	err = cli.AddEventListener(listener)
	if err != nil {
		log.Fatal(err)
	}

	domain := os.Getenv("DOMAIN_TLD")
	network := os.Getenv("DOCKER_NETWORK")

	log.Println("Listening events")
	for {
		event := <-listener

		if event.Type == "container" && event.Action == "create" {
			containerName := event.Actor.Attributes["name"]
			log.Printf("New container (%s) created\n", containerName)

			project, hasProject := event.Actor.Attributes["com.docker.compose.project"]
			service, hasService := event.Actor.Attributes["com.docker.compose.service"]
			oneoff := event.Actor.Attributes["com.docker.compose.oneoff"]

			if hasProject && hasService {
				config := docker.NetworkConnectionOptions{Container: event.Actor.ID}

				if oneoff == "False" {
					alias := service + "." + project + "." + domain
					log.Printf("Attaching %s to the %s network with alias %s\n", containerName, network, alias)
					config.EndpointConfig = &docker.EndpointConfig{
						Aliases: []string{alias},
					}
				} else {
					log.Printf("Attaching %s to the %s network\n", event.Actor.ID, network)
				}

				err := cli.ConnectNetwork(network, config)
				if err != nil {
					log.Fatal(err)
				}
			}
		}
	}

}
