import { Entity, Column, PrimaryColumn, OneToMany } from 'typeorm';
import { Report } from './report.entity';

@Entity('projects')
export class Project {
  @PrimaryColumn()
  project_id: string;

  @Column()
  name: string;

  @Column()
  client_id: string;

  @Column({ type: 'float', default: 0 })
  current_consumption: number;

  @OneToMany(() => Report, (report) => report.project)
  reports: Report[];
}
