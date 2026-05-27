import { Entity, Column, PrimaryColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Project } from './project.entity';

@Entity('reports')
export class Report {
  @PrimaryColumn()
  report_id: string;

  @Column()
  project_id: string;

  @Column()
  month: string;

  @Column({ type: 'float' })
  total_cost: number;

  @Column({ nullable: true })
  integrity_hash: string;

  @ManyToOne(() => Project, (project) => project.reports)
  @JoinColumn({ name: 'project_id' })
  project: Project;
}
